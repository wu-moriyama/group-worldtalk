package FCC::Class::Card;
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
	#cardsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		crd_id             => "識別ID",
		member_id          => "会員識別ID",
		mbract_id          => "入出金識別ID",
		pln_id             => "プラン識別ID",
		auto_id            => "自動課金識別ID",
		crd_cdate          => "生成日時",
		crd_rdate          => "決済確定日時",
		crd_price          => "課金額",
		crd_point          => "付与ポイント",
		crd_subscription   => "自動課金フラグ",
		crd_ref            => "リファレンストランザクションフラグ",
		crd_success        => "決済完了フラグ",
		crd_txn_id         => "PayPal トランザクションID",
		crd_payer_id       => "PayPal IPN会員ID",
		crd_receipt_id     => "PayPal IPN受領番号",
		crd_ipn_message    => "PayPal IPNメッセージ",
		crd_nvp_message    => "PayPal NVPメッセージ"
	};
	#CSVの各カラム名と名称とepoch秒フラグ（crd_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		["cards.crd_id",           "識別ID（請求書ID）"],
		["cards.member_id",        "会員識別ID"],
		["members.member_lastname",  "姓"],
		["members.member_firstname", "名"],
		["members.member_handle",    "ニックネーム"],
		["cards.mbract_id",        "入出金識別ID"],
		["cards.pln_id",           "プラン識別ID"],
		["cards.auto_id",          "自動課金識別ID"],
		["cards.crd_cdate",        "生成日時", 1],
		["cards.crd_rdate",        "決済確定日時", 1],
		["cards.crd_price",        "課金額"],
		["cards.crd_point",        "付与ポイント"],
		["cards.crd_subscription", "自動課金フラグ", 0, { "0" => "スポット",  "1" => "自動課金" }],
		["cards.crd_ref",          "リファレンストランザクションフラグ", 0, { "0" => "ウェブページからの決済", "1" => "自動課金のバッチ決済（リファレンストランザクション）"}],
		["cards.crd_success",      "決済完了フラグ", 0, { "1" => "成功", "2" => "失敗", "3" => "保留" }],
		["cards.crd_txn_id",       "PayPal 取引参照番号（取引ID）"],
		["cards.crd_payer_id",     "PayPal IPN会員ID"],
		["cards.crd_receipt_id",   "PayPal 受領書ID"],
		["cards.crd_ipn_message",  "PayPal IPNメッセージ"],
		["cards.crd_nvp_message",  "PayPal NVPメッセージ"]
	];
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
	$rec->{crd_cdate} = $now;
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
	my $crd_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO cards (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$crd_id = $dbh->{mysql_insertid};
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to cards table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#情報を取得
	my $card = $self->get($crd_id);
	#
	return $card;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないcrd_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $crd_id = $ref->{crd_id};
	if( ! defined $crd_id || $crd_id =~ /[^\d]/) {
		croak "the value of crd_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#カテゴリー情報を取得
	my $card = $self->get($crd_id);
	if( ! $card ) {
		croak "the specified crd_id is not found.";
	}
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "crd_id") { next; }
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
	my $sql = "UPDATE cards SET " . join(",", @sets) . " WHERE crd_id=${crd_id}";
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
		my $msg = "failed to update a record in cards table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#情報を取得
	my $card_new = $self->get($crd_id);
	#
	return $card_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないcrd_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $crd_id) = @_;
	#識別IDのチェック
	if( ! defined $crd_id || $crd_id =~ /[^\d]/) {
		croak "the value of crd_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $card = $self->get($crd_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM cards WHERE crd_id=${crd_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in cards table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $card;
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
	my($self, $crd_id) = @_;
	if( ! $crd_id || $crd_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT cards.*, members.* FROM cards";
	$sql .= " LEFT JOIN members ON cards.member_id=members.member_id";
	$sql .= " WHERE cards.crd_id=${crd_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
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
#			crd_id => 識別ID,
#			auto_id => 自動課金識別ID,
#			member_id => 会員識別ID,
#			pln_id => プラン識別ID,
#			crd_success => 決済完了フラグ,
#			crd_txn_id => PayPal トランザクションID,
#			crd_payer_id => PayPal IPN会員ID,
#			crd_receipt_id => PayPal IPN受領番号,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['buz_id', "DESC"] ]
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
		'crd_id',
		'auto_id',
		'member_id',
		'pln_id',
		'crd_success',
		'crd_txn_id',
		'crd_payer_id',
		'crd_receipt_id',
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
		sort =>[ ['crd_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(crd|member|auto)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "crd_success") {
			if($v !~ /^\d$/) {
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
				if($key !~ /^(crd_id)$/) { croak "the value of sort in parameters is invalid."; }
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
	for( my $i=0; $i<@{$self->{csv_cols}}; $i++ ) {
		my $r = $self->{csv_cols}->[$i];
		push(@col_list, $r->[0]);
		push(@col_name_list, $r->[1]);
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
	if(defined $params->{crd_id}) {
		push(@wheres, "cards.crd_id=$params->{crd_id}");
	}
	if(defined $params->{auto_id}) {
		push(@wheres, "cards.auto_id=$params->{auto_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "cards.member_id=$params->{member_id}");
	}
	if(defined $params->{pln_id}) {
		my $q_v = $dbh->quote($params->{pln_id});
		push(@wheres, "cards.pln_id=${q_v}");
	}
	if(defined $params->{crd_txn_id}) {
		my $q_v = $dbh->quote($params->{crd_txn_id});
		push(@wheres, "cards.crd_txn_id=${q_v}");
	}
	if(defined $params->{crd_payer_id}) {
		my $q_v = $dbh->quote($params->{crd_payer_id});
		push(@wheres, "cards.crd_payer_id=${q_v}");
	}
	if(defined $params->{crd_receipt_id}) {
		my $q_v = $dbh->quote($params->{crd_receipt_id});
		push(@wheres, "cards.crd_receipt_id=${q_v}");
	}
	if(defined $params->{crd_success}) {
		push(@wheres, "cards.crd_success=$params->{crd_success}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM cards";
		$sql .= " LEFT JOIN members ON cards.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "cards.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_arrayref ) {
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
#			crd_id => 識別ID,
#			auto_id => 自動課金識別ID,
#			member_id => 会員識別ID,
#			pln_id => プラン識別ID,
#			crd_success => 決済完了フラグ,
#			crd_txn_id => PayPal トランザクションID,
#			crd_payer_id => PayPal IPN会員ID,
#			crd_receipt_id => PayPal IPN受領番号,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['buz_id', "DESC"] ]
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
		'crd_id',
		'auto_id',
		'member_id',
		'pln_id',
		'crd_success',
		'crd_txn_id',
		'crd_payer_id',
		'crd_receipt_id',
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
		sort =>[ ['crd_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(crd|member|auto)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "crd_success") {
			if($v !~ /^\d$/) {
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
				if($key !~ /^(crd_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{crd_id}) {
		push(@wheres, "cards.crd_id=$params->{crd_id}");
	}
	if(defined $params->{auto_id}) {
		push(@wheres, "cards.auto_id=$params->{auto_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "cards.member_id=$params->{member_id}");
	}
	if(defined $params->{pln_id}) {
		my $q_v = $dbh->quote($params->{pln_id});
		push(@wheres, "cards.pln_id=${q_v}");
	}
	if(defined $params->{crd_txn_id}) {
		my $q_v = $dbh->quote($params->{crd_txn_id});
		push(@wheres, "cards.crd_txn_id=${q_v}");
	}
	if(defined $params->{crd_payer_id}) {
		my $q_v = $dbh->quote($params->{crd_payer_id});
		push(@wheres, "cards.crd_payer_id=${q_v}");
	}
	if(defined $params->{crd_receipt_id}) {
		my $q_v = $dbh->quote($params->{crd_receipt_id});
		push(@wheres, "cards.crd_receipt_id=${q_v}");
	}
	if(defined $params->{crd_success}) {
		push(@wheres, "cards.crd_success=$params->{crd_success}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(crd_id) FROM cards";
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
		my $sql = "SELECT cards.*, members.* FROM cards";
		$sql .= " LEFT JOIN members ON cards.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "cards.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
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
	my %crd_cdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{crd_cdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %crd_cdate_fmt ) {
		$ref->{"crd_cdate_${k}"} = $v;
	}
	my %crd_rdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{crd_rdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %crd_rdate_fmt ) {
		$ref->{"crd_rdate_${k}"} = $v;
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

1;
