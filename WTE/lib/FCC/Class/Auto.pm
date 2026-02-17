package FCC::Class::Auto;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::Date::Utils;
use Unicode::Japanese;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#autosテーブルの全カラム名のリスト
	$self->{table_cols} = {
		auto_id          => "識別ID",
		member_id        => "会員識別ID",
		crd_id           => "カード決済識別ID",
		pln_id           => "プラン識別ID",
		auto_cdate       => "レコード生成日時",
		auto_price       => "月額料金",
		auto_point       => "月額ポイント",
		auto_day         => "決済日",
		auto_last_ym     => "最終ポイント付与年月",
		auto_status      => "ステータス",
		auto_count       => "課金回数",
		auto_sdate       => "自動課金停止日時",
		auto_stop_reason => "自動課金停止理由",
		auto_mdate       => "最終課金処理日時",
		auto_txn_id      => "PayPal 取引参照番号（取引ID）"
	};
	#CSVの各カラム名と名称とepoch秒フラグ（auto_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		["autos.auto_id",            "自動課金識別ID"],
		["autos.member_id",          "$self->{conf}->{member_caption}識別ID"],
		["members.member_lastname",  "姓"],
		["members.member_firstname", "名"],
		["members.member_handle",    "ニックネーム"],
		["autos.crd_id",             "カード決済識別ID"],
		["autos.pln_id",             "プラン識別ID"],
		["autos.auto_cdate",         "レコード生成日時", 1],
		["autos.auto_price",         "月額料金"],
		["autos.auto_point",         "月額ポイント"],
		["autos.auto_day",           "決済日"],
		["autos.auto_last_ym",       "最終ポイント付与年月"],
		["autos.auto_status",        "ステータス", 0, { "0" => "取りやめ", "1" => "継続中" }],
		["autos.auto_count",         "課金回数"],
		["autos.auto_sdate",         "自動課金停止日時", 1],
		["autos.auto_stop_reason",   "自動課金停止理由", 0, { "0" => "継続中", "1" => "会員自身による解約", "2" => "クレジット自動課金失敗", "3" => "会員退会", "4" => "新プランへ更新", "5" => "会員ステータスが本会員でない" }],
		["autos.auto_mdate",         "最終課金処理日時", 1],
		["autos.auto_txn_id",        "PayPal 取引参照番号（取引ID）"]
	];
}

#---------------------------------------------------------------------
#■自動課金会員かどうかをチェック
#---------------------------------------------------------------------
#[引数]
#	1: 会員識別ID
#[戻り値]
#	自動課金なら該当のレコードのhashrefを返す
#	そうでなければundefを返す
#---------------------------------------------------------------------
sub is_subscription_member {
	my($self, $member_id) = @_;
	#識別IDのチェック
	if( ! defined $member_id || $member_id =~ /[^\d]/) {
		croak "the value of member_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	my $sql = "SELECT autos.*, members.*, cards.* FROM autos";
	$sql .= " LEFT JOIN members ON autos.member_id=members.member_id";
	$sql .= " LEFT JOIN cards ON autos.crd_id=cards.crd_id";
	$sql .= " WHERE autos.member_id=${member_id} AND autos.auto_status=1";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref && $ref->{pln_id}) {
		my $q_pln_id = $dbh->quote($ref->{pln_id});
		my $pln = $dbh->selectrow_hashref("SELECT * FROM plans WHERE pln_id=${q_pln_id}");
		if($pln) {
			while( my($k, $v) = each %{$pln} ) {
				$ref->{$k} = $v;
			}
		}
	}
	#
	if($ref) {
		$self->add_info($ref);
		$self->member_info($ref);
		$self->add_datetime_info($ref);
	}
	#
	return $ref;
}

#---------------------------------------------------------------------
#■継続中の自動課金管理を停止
#---------------------------------------------------------------------
#[引数]
#	1: hashref
#		{
#			member_id => 会員識別ID,
#			auto_stop_reason => 停止理由コード
#		}
#[戻り値]
#	停止したレコードの数（0か1が返る）
#---------------------------------------------------------------------
sub stop_subscription {
	my($self, $p) = @_;
	unless($p) {
		croak "invalid parameter.";
	}
	my $member_id = $p->{member_id};
	my $auto_stop_reason = $p->{auto_stop_reason};
	#識別IDのチェック
	if( ! defined $member_id || $member_id =~ /[^\d]/) {
		croak "the value of member_id in parameters is invalid.";
	}
	if( ! defined $auto_stop_reason || $auto_stop_reason =~ /[^\d]/) {
		croak "the value of auto_stop_reason in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#sql
	my $now = time;
	my $sql = "UPDATE autos SET auto_status=0, auto_stop_reason=${auto_stop_reason}, auto_sdate=${now} WHERE member_id=${member_id} AND auto_status=1";
	#UPDATE
	my $updated;
	eval {
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a record in autos table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#
	return $updated;
}

#---------------------------------------------------------------------
#■レコード新規登録
#---------------------------------------------------------------------
#[引数]
#	1: hashref
#[戻り値]
#	登録したhashref
#---------------------------------------------------------------------
sub add {
	my($self, $ref) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	my $now = time;
	$rec->{auto_cdate} = $now;
	#SQL生成
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		my $q_v;
		if($v eq "") {
			$q_v = "NULL";
		} else {
			$q_v = $dbh->quote($v);
		}
		push(@vlist, $q_v);
	}
	#INSERT
	my $auto_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO autos (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$auto_id = $dbh->{mysql_insertid};
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to autos table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#情報を取得
	my $auto = $self->get($auto_id);
	#
	return $auto;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないauto_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $auto_id = $ref->{auto_id};
	if( ! defined $auto_id || $auto_id =~ /[^\d]/) {
		croak "the value of auto_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $auto = $self->get($auto_id);
	if( ! $auto ) {
		croak "the specified auto_id is not found.";
	}
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "auto_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#dctsテーブルUPDATE用のSQL生成
	my @sets;
	while( my($k, $v) = each %{$rec} ) {
		my $q_v;
		if($v eq "") {
			$q_v = "NULL";
		} else {
			$q_v = $dbh->quote($v);
		}
		push(@sets, "${k}=${q_v}");
	}
	my $sql = "UPDATE autos SET " . join(",", @sets) . " WHERE auto_id=${auto_id}";
	#UPDATE
	my $updated;
	my $last_sql;
	eval {
		$last_sql = $sql;
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a record in autos table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#情報を取得
	my $auto_new = $self->get($auto_id);
	#
	return $auto_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないauto_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $auto_id) = @_;
	#識別IDのチェック
	if( ! defined $auto_id || $auto_id =~ /[^\d]/) {
		croak "the value of auto_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $auto = $self->get($auto_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM autos WHERE auto_id=${auto_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in autos table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $auto;
}

#---------------------------------------------------------------------
#■識別IDからレコード取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $auto_id) = @_;
	if( ! $auto_id || $auto_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT autos.*, members.* FROM autos";
	$sql .= " LEFT JOIN members ON autos.member_id=members.member_id";
	$sql .= " WHERE autos.auto_id=${auto_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_info($ref);
		$self->member_info($ref);
		$self->add_datetime_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			auto_id => 識別ID,
#			member_id => 会員識別ID,
#			crd_id => カード決済識別ID,
#			auto_status => ステータス,
#			auto_stop_reason => 課金停止理由,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['auto_id', "DESC"] ]
#		}
#
#[戻り値]
#	検索結果を格納したhashref
#		{
#			tsv => CSVデータ,
#			length => CSVデータのサイズ（バイト）
#		}
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_csv {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'auto_id',
		'member_id',
		'crd_id',
		'auto_status',
		'auto_stop_reason',
		'sort',
		'charcode',
		'returncode'
	);
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		offset => 0,
		limit => 20,
		sort =>[ ['auto_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(auto|crd|member)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k =~ /^auto_(status|stop_reason)$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(auto_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#
	if(defined $params->{charcode}) {
		if($params->{charcode} !~ /^(utf8|sjis|euc\-jp)$/) {
			croak "the value of charcode is invalid.";
		}
	} else {
		$params->{charcode} = "sjis";
	}
	if(defined $params->{returncode}) {
		if($params->{returncode} !~ /^(\x0d\x0a|\x0d|\x0a)$/) {
			croak "the value of returncode is invalid.";
		}
	} else {
		$params->{returncode} = "\x0a";
	}
	#カラムの一覧
	my @col_list;
	my @col_name_list;
#	my @col_epoch_index_list;
	for( my $i=0; $i<@{$self->{csv_cols}}; $i++ ) {
		my $r = $self->{csv_cols}->[$i];
		push(@col_list, $r->[0]);
		push(@col_name_list, $r->[1]);
#		if($r->[2]) {
#			push(@col_epoch_index_list, $i);
#		}
	}
	#ヘッダー行
	my $head_line = $self->make_csv_line(\@col_name_list);
	if($params->{charcode} ne "utf8") {
		$head_line = Unicode::Japanese->new($head_line, "utf8")->conv($params->{charcode});
	}
	my $csv = $head_line . $params->{returncode};
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{auto_id}) {
		push(@wheres, "autos.auto_id=$params->{auto_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "autos.member_id=$params->{member_id}");
	}
	if(defined $params->{crd_id}) {
		push(@wheres, "autos.crd_id=$params->{crd_id}");
	}
	if(defined $params->{auto_status}) {
		push(@wheres, "autos.auto_status=$params->{auto_status}");
	}
	if(defined $params->{auto_stop_reason}) {
		push(@wheres, "autos.auto_stop_reason=$params->{auto_stop_reason}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM autos";
		$sql .= " LEFT JOIN members ON autos.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "autos.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_arrayref ) {
#			for my $idx (@col_epoch_index_list) {
#				my @tm = FCC::Class::Date::Utils->new(time=>$ref->[$idx], tz=>$self->{conf}->{tz})->get(1);
#				$ref->[$idx] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
#			}
			for( my $i=0; $i<@{$ref}; $i++ ) {
				my $v = $ref->[$i];
				if( ! defined $v ) {
					$ref->[$i] = "";
				}
				if($self->{csv_cols}->[$i]->[2] && $ref->[$i]) {
					my @tm = FCC::Class::Date::Utils->new(time=>$ref->[$i], tz=>$self->{conf}->{tz})->get(1);
					$ref->[$i] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
				} elsif($self->{csv_cols}->[$i]->[3] && $ref->[$i] ne "") {
					my $cap = $self->{csv_cols}->[$i]->[3]->{$ref->[$i]};
					if($cap) {
						$ref->[$i] = $cap;
					}
				}
			}
			my $line = $self->make_csv_line($ref);
			$line =~ s/(\x0d|\x0a)//g;
			if($params->{charcode} ne "utf8") {
				$line = Unicode::Japanese->new($line, "utf8")->conv($params->{charcode});
			}
			$csv .= "${line}$params->{returncode}";
		}
		$sth->finish();
	}
	#
	my $res = {};
	$res->{csv} = $csv;
	$res->{length} = length $csv;
	#
	return $res;
}

sub make_csv_line {
	my($self, $ary) = @_;
	my @cols;
	for my $elm (@{$ary}) {
		my $v = $elm;
		$v =~ s/\"/\"\"/g;
		$v = '"' . $v . '"';
		push(@cols, $v);
	}
	my $line = join(",", @cols);
	return $line;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			auto_id => 識別ID,
#			member_id => 会員識別ID,
#			crd_id => カード決済識別ID,
#			auto_status => ステータス,
#			auto_stop_reason => 課金停止理由,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['auto_id', "DESC"] ]
#		}
#
#[戻り値]
#	検索結果を格納したhashref
#		{
#			list => 各レコードを格納したhashrefのarrayref,
#			hit => 検索ヒット数,
#			fetch => フェッチしたレコード数,
#			start => 取り出したレコードの開始番号（offset+1, ただしhit=0の場合はstartも0となる）,
#			end => 取り出したレコードの終了番号（offset+fetch, ただしhit=0の場合はendも0となる）,
#			params => 検索条件を格納したhashref
#		}
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_list {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'auto_id',
		'member_id',
		'crd_id',
		'auto_status',
		'auto_stop_reason',
		'offset',
		'limit',
		'sort',
	);
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		offset => 0,
		limit => 20,
		sort =>[ ['auto_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(auto|crd|member)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k =~ /^auto_(status|stop_reason)$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "offset") {
			if($v =~ /[^\d]/) {
				croak "the value of offset in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "limit") {
			if($v =~ /[^\d]/) {
				croak "the value of limit in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(auto_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{auto_id}) {
		push(@wheres, "autos.auto_id=$params->{auto_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "autos.member_id=$params->{member_id}");
	}
	if(defined $params->{crd_id}) {
		push(@wheres, "autos.crd_id=$params->{crd_id}");
	}
	if(defined $params->{auto_status}) {
		push(@wheres, "autos.auto_status=$params->{auto_status}");
	}
	if(defined $params->{auto_stop_reason}) {
		push(@wheres, "autos.auto_stop_reason=$params->{auto_stop_reason}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(auto_id) FROM autos";
		if(@wheres) {
			$sql .= " WHERE ";
			$sql .= join(" AND ", @wheres);
		}
		($hit) = $dbh->selectrow_array($sql);
	}
	$hit += 0;
	#SELECT
	my @list;
	{
		my $sql = "SELECT autos.*, members.* FROM autos";
		$sql .= " LEFT JOIN members ON autos.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "autos.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			$self->add_info($ref);
			$self->add_datetime_info($ref);
			$self->member_info($ref);
			push(@list, $ref);
		}
		$sth->finish();
	}
	#
	my $res = {};
	$res->{list} = \@list;
	$res->{hit} = $hit;
	$res->{fetch} = scalar @list;
	$res->{start} = 0;
	if($res->{fetch} > 0) {
		$res->{start} = $params->{offset} + 1;
		$res->{end} = $params->{offset} + $res->{fetch};
	}
	$res->{params} = $params;
	#
	return $res;
}

sub add_datetime_info {
	my($self, $ref) = @_;
	my %auto_cdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{auto_cdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %auto_cdate_fmt ) {
		$ref->{"auto_cdate_${k}"} = $v;
	}
	my %auto_mdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{auto_mdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %auto_mdate_fmt ) {
		$ref->{"auto_mdate_${k}"} = $v;
	}
	my %auto_sdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{auto_sdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %auto_sdate_fmt ) {
		$ref->{"auto_sdate_${k}"} = $v;
	}
}

sub member_info {
	my($self, $ref) = @_;
	unless($ref) { return; }
	my $member_id = $ref->{member_id};
	unless($member_id) { return; }
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"member_logo_${s}_url"} = "$self->{conf}->{member_logo_dir_url}/${member_id}.${s}.$self->{conf}->{member_logo_ext}";
		$ref->{"member_logo_${s}_w"} = $self->{conf}->{"member_logo_${s}_w"};
		$ref->{"member_logo_${s}_h"} = $self->{conf}->{"member_logo_${s}_h"};
	}
}

sub add_info {
	my($self, $ref) = @_;
	$ref->{auto_stoppable} = 0;
	if( $ref->{auto_count} >= $self->{conf}->{point_auto_min_month} ) {
		$ref->{auto_stoppable} = 1;
	}
}

1;
