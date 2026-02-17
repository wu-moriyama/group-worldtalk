package FCC::Class::Fml;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::Date::Utils;
use FCC::Class::String::Checker;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#fmlsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		fml_id      => "識別ID",
		fml_title   => "タイトル",
		fml_base    => "配信基準日",
		fml_days    => "基準日から日数",
		fml_cond    => "配信条件",
		fml_content => "テンプレートデータ",
		fml_memo    => "備考"
	};
	#
}

#---------------------------------------------------------------------
#■新規登録・編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in) = @_;
	my %cap = %{$self->{table_cols}};
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#タイトル
		if($k eq "fml_title") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は100文字以内で指定してください。"]);
			}
		#配信基準日
		} elsif($k eq "fml_base") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(1|2)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#基準日から日数
		} elsif($k eq "fml_days") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で指定してください。"]);
			} elsif($v < 1 || $v > 999) {
				push(@errs, [$k, "\"$cap{$k}\" は 1 ～ 999 までの日数を指定してください。"]);
			}
		#配信条件
		} elsif($k eq "fml_cond") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1|2|3)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#テンプレートデータ
		} elsif($k eq "fml_content") {
			if($v eq "") {

			} elsif($len > 50000) {
				push(@errs, [$k, "\"$cap{$k}\" は50000文字以内で入力してください。"]);
			}
		#備考
		} elsif($k eq "fml_memo") {
			if($v eq "") {

			} elsif($len > 1000) {
				push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
			}
		}
	}
	#
	return @errs;
}

#---------------------------------------------------------------------
#■識別IDからメッセージ取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $fml_id) = @_;
	if( ! $fml_id || $fml_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT * FROM fmls";
	$sql .= " WHERE fml_id=${fml_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	return $ref;
}

#---------------------------------------------------------------------
#■登録
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
	#SQL生成
	my $sql = $self->make_insert_sql($dbh, "fmls", $rec);
	#INSERT
	my $fml_id;
	my $last_sql;
	eval {
		$last_sql = $sql;
		$dbh->do($last_sql);
		$fml_id = $dbh->{mysql_insertid};
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to fmls table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#情報を取得
	my $fml = $self->get($fml_id);
	#
	return $fml;
}

sub make_insert_sql {
	my($self, $dbh, $tbl, $rec) = @_;
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
	my $sql = "INSERT INTO ${tbl} (" . join(", ", @klist) . ") VALUES (" . join(", ", @vlist) . ")";
	return $sql;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないfml_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $fml_id = $ref->{fml_id};
	if( ! defined $fml_id || $fml_id =~ /[^\d]/) {
		croak "the value of fml_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $fml_old = $self->get($fml_id);
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "fml_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#fmlsテーブルUPDATE用のSQL生成
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
	my $sql = "UPDATE fmls SET " . join(",", @sets) . " WHERE fml_id=${fml_id}";
	#UPDATE
	my $updated;
	eval {
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a coupon record in fmls table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#クーポン情報を取得
	my $fml_new = $self->get($fml_id);
	#
	return $fml_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないfml_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $fml_id) = @_;
	#識別IDのチェック
	if( ! defined $fml_id || $fml_id =~ /[^\d]/) {
		croak "the value of fml_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $fml = $self->get($fml_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM fmls WHERE fml_id=${fml_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in fmls table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $fml;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			fml_id => 識別ID,
#			fml_base => 配信基準日,
#			fml_cond => 配信条件,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['fml_id', "DESC"] ]
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
		'fml_id',
		'fml_base',
		'fml_cond',
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
		sort =>[ ['fml_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^fml_(id|base|cond)$/) {
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
				if($key !~ /^(fml_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{fml_id}) {
		push(@wheres, "fml_id=$params->{fml_id}");
	}
	if(defined $params->{fml_base}) {
		push(@wheres, "fml_base=$params->{fml_base}");
	}
	if(defined $params->{fml_cond}) {
		push(@wheres, "fml_cond=$params->{fml_cond}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(fml_id) FROM fmls";
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
		my $sql = "SELECT * FROM fmls";
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
		$sql .= " LIMIT $params->{offset}";
		if($params->{limit}) {
			$sql .= ", $params->{limit}";
		}
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
