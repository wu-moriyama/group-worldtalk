package FCC::Class::Ann;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Image::Magick;
use Digest::MD5;
use FCC::Class::Log;
use FCC::Class::String::Checker;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{memd} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{db} = $args{db};
	#
	$self->{memcache_key_1} = "ann_list_1";	# 代理店向け
	$self->{memcache_key_2} = "ann_list_2";	# 会員向け
	$self->{memcache_key_3} = "ann_list_3";	# 講師向け
	$self->{memcache_key_4} = "ann_list_4";	# サイト向け
	#annsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		ann_id      => '識別ID',
		ann_target  => '配信先',
		ann_cdate   => '登録日時',
		ann_title   => 'タイトル',
		ann_content => '本文'
	};
}

#---------------------------------------------------------------------
#■ダッシュボード用のお知らせ一覧取得
#---------------------------------------------------------------------
#[引数]
#	1.配信先コード（1, 2, 3, 4）
#[戻り値]
#	arrayref
#---------------------------------------------------------------------
sub get_list_for_dashboard {
	my($self, $ann_target) = @_;
	if( ! defined $ann_target || $ann_target !~ /^(1|2|3|4)$/ ) {
		croak "the value of ann_target in parameters is invalid.";
	}
	#memcacheから取得
	{
		my $list = $self->get_list_for_dashboard_from_memcache($ann_target);
		if( $list && ref($list) eq "ARRAY" ) {
			return $list;
		}
	}
	#DBから取得
	{
		my $list = $self->get_list_for_dashboard_from_db($ann_target);
		#memcacheにセット
		$self->set_to_memcache($ann_target, $list);
		#
		return $list;
	}
}

sub set_to_memcache {
	my($self, $ann_target, $list) = @_;
	if( ! defined $ann_target || $ann_target !~ /^(1|2|3|4)$/ ) {
		croak "the value of ann_target in parameters is invalid.";
	}
	my $mem_key = $self->{"memcache_key_${ann_target}"};
	my $mem = $self->{memd}->set($mem_key, $list);
	unless($mem) {
		my $msg = "failed to set a ann record to memcache. : ann_target=${ann_target}";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
}

sub get_list_for_dashboard_from_memcache {
	my($self, $ann_target) = @_;
	if( ! defined $ann_target || $ann_target !~ /^(1|2|3|4)$/ ) {
		croak "the value of ann_target in parameters is invalid.";
	}
	my $mem_key = $self->{"memcache_key_${ann_target}"};
	my $list = $self->{memd}->get($mem_key);
	if( ! $list || ref($list) ne "ARRAY" ) { return undef; }
	return $list;
}

sub get_list_for_dashboard_from_db {
	my($self, $ann_target) = @_;
	if( ! defined $ann_target || $ann_target !~ /^(1|2|3|4)$/ ) {
		croak "the value of ann_target in parameters is invalid.";
	}
	my $limit = $self->{conf}->{"ann_list_limit_${ann_target}"};
	my $res = $self->get_list({ ann_target => $ann_target, offset => 0, limit => $limit });
	return $res->{list};
}

#memcashをアップデート
sub update_memcache {
	my($self) = @_;
	for( my $i=1; $i<=4; $i++ ) {
		my $list = $self->get_list_for_dashboard_from_db($i);
		$self->set_to_memcache($i, $list);
	}
}


#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#	3.モード（add or mod）指定がない場合は add として処理される
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in, $mode) = @_;
	my %cap = %{$self->{table_cols}};
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#配信先
		if($k eq "ann_target") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(1|2|3|4)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値を送信されました。"]);
			}
		#タイトル
		} elsif($k eq "ann_title") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 20) {
				push(@errs, [$k, "\"$cap{$k}\" は20文字以内で入力してください。"]);
			}
		#本文
		} elsif($k eq "ann_content") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 1000) {
				push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
			}
		}
	}
	#
	return @errs;
}

#---------------------------------------------------------------------
#■新規登録
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	失敗すればcroakする。
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
	$rec->{ann_cdate} = $now;
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
	my $ann_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO anns (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$self->{db}->{dbh}->do($last_sql);
		$ann_id = $dbh->{mysql_insertid};
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to insert a record to anns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#お知らせ情報を取得
	my $ann = $self->get_from_db($ann_id);
	#memcashをアップデート
	$self->update_memcache();
	#
	return $rec;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないann_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $ann_id = $ref->{ann_id};
	if( ! defined $ann_id || $ann_id =~ /[^\d]/) {
		croak "the value of ann_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#お知らせ情報を取得
	my $ann_old = $self->get_from_db($ann_id);
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "ann_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#annsテーブルUPDATE用のSQL生成
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
	my $sql = "UPDATE anns SET " . join(",", @sets) . " WHERE ann_id=${ann_id}";
	#UPDATE
	my $updated;
	eval {
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a ann record in anns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#お知らせ情報を取得
	my $ann_new = $self->get_from_db($ann_id);
	#memcashをアップデート
	$self->update_memcache();
	#
	return $ann_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないann_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $ann_id) = @_;
	#識別IDのチェック
	if( ! defined $ann_id || $ann_id =~ /[^\d]/) {
		croak "the value of ann_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#お知らせ情報を取得
	my $ann = $self->get_from_db($ann_id);
	#SQL生成
	my $sql = "DELETE FROM anns WHERE ann_id=${ann_id}";
	#UPDATE
	my $deleted;
	eval {
		$deleted = $self->{db}->{dbh}->do($sql);
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to delete a ann record in anns table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#memcashをアップデート
	$self->update_memcache();
	#
	return $ann;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
#---------------------------------------------------------------------
sub get {
	my($self, $ann_id) = @_;
	my $ref = $self->get_from_db($ann_id);
	return $ref;
}

#---------------------------------------------------------------------
#■識別IDからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db {
	my($self, $ann_id) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_ann_id = $dbh->quote($ann_id);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM anns WHERE ann_id=${q_ann_id}");
	#
	return $ref;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			ann_id => 識別ID,
#			ann_target => 配信先,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['ann_id', "DESC"] ]
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
	my @param_key_list = ('ann_id', 'ann_target', 'offset', 'limit', 'sort');
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k}) {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		offset => 0,
		limit => 20,
		sort =>[ ['ann_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "ann_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "ann_target") {
			if($v !~ /^(1|2|3|4)$/) {
				delete $params->{$k};
			}
		} elsif($k eq "offset") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
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
				if($key !~ /^(ann_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{ann_id}) {
		push(@wheres, "ann_id=$params->{ann_id}");
	}
	if(defined $params->{ann_target}) {
		push(@wheres, "ann_target=$params->{ann_target}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(ann_id) FROM anns";
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
		my $sql = "SELECT * FROM anns";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
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


1;
