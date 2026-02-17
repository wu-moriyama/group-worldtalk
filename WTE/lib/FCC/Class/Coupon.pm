package FCC::Class::Coupon;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Date::Pcalc;
use Data::Random::String;
use FCC::Class::Log;
use FCC::Class::String::Checker;
use FCC::Class::Date::Utils;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#couponsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		coupon_id     => "クーポン識別ID",
		seller_id     => "代理店識別ID",
		coupon_code   => "クーポンコード",
		coupon_cdate  => "発行日時",
		coupon_expire => "有効期限（日付）",
		coupon_title  => "タイトル",
		coupon_price  => "発行金額",
		coupon_max    => "クーポン登録$self->{conf}->{member_caption}上限",
		coupon_num    => "クーポン登録$self->{conf}->{member_caption}数",
		coupon_status => "状態",
		coupon_note   => "配布予定場所"
	};
	#CSVの各カラム名と名称とepoch秒フラグ（coupon_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		['coupon_id',     "クーポン識別ID"],
		['seller_id',     "代理店識別ID"],
		['coupon_code',   "クーポンコード"],
		['coupon_cdate',  "発行日時", 1],
		['coupon_expire', "有効期限（日付）"],
		['coupon_title',  "タイトル"],
		['coupon_price',  "発行金額"],
		['coupon_max',    "クーポン登録$self->{conf}->{member_caption}上限"],
		['coupon_num',    "クーポン登録$self->{conf}->{member_caption}数"],
		['coupon_status', "状態"],
		['coupon_note',   "配布予定場所"]
	];
	#今日の日付
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	$self->{today} = "$tm[0]-$tm[1]-$tm[2]";
}

#---------------------------------------------------------------------
sub is_available {
	my($self, $ref) = @_;
	if( $ref->{coupon_status} == 1 && $ref->{coupon_expire} ge $self->{today} ) {
		return 1;
	} else {
		return 0;
	}
}

#---------------------------------------------------------------------
#■coupon_numをインクリメント
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	なし
#---------------------------------------------------------------------
sub incr_num {
	my($self, $coupon_id) = @_;
	my $dbh = $self->{db}->connect_db();
	my $sql = "UPDATE coupons SET coupon_num=coupon_num+1 WHERE coupon_id=${coupon_id}";
	eval {
		$dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a coupon record in coupons table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
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
	#
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#有効期限（日付）
		if($k eq "coupon_expire") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /^(\d{4})\-(\d{2})\-(\d{2})$/) {
				my $y = $1 + 0;
				my $m = $2 + 0;
				my $d = $3 + 0;
				if( Date::Pcalc::check_date($y, $m, $d) ) {
					if( $v lt $self->{today} ) {
						push(@errs, [$k, "\"$cap{$k}\" に過去の日付けを指定することはできません。"]);
					}
				} else {
					push(@errs, [$k, "\"$cap{$k}\" に指定された日付が不適切です。"]);
				}
			} else {
				push(@errs, [$k, "\"$cap{$k}\" YYYY-MM-DD形式で指定してください。"]);
			}
		#タイトル
		} elsif($k eq "coupon_title") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 50) {
				push(@errs, [$k, "\"$cap{$k}\" は50文字以内で入力してください。"]);
			}
		#発行金額
		} elsif($k eq "coupon_price") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
			} elsif($v < 100 || $v > 100000 ) {
				push(@errs, [$k, "\"$cap{$k}\" は100～100000までの金額を指定してください。"]);
			}
		#クーポン登録会員上限
		} elsif($k eq "coupon_max") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"$cap{$k}\" は半角数字で入力してください。"]);
			} elsif($v < 1 || $v > 100000 ) {
				push(@errs, [$k, "\"$cap{$k}\" は1～100000までの人数を指定してください。"]);
			}
		#状態
		} elsif($k eq "coupon_status") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#配布予定場所
		} elsif($k eq "coupon_note") {
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
	$rec->{coupon_cdate} = $now;
	$rec->{coupon_code} = $self->make_coupon_code();
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
	my $coupon_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO coupons (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$self->{db}->{dbh}->do($last_sql);
		$coupon_id = $dbh->{mysql_insertid};
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to insert a record to coupons table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#クーポン情報を取得
	my $coupon = $self->get_from_db($coupon_id);
	#
	return $coupon;
}

sub make_coupon_code {
	my($self) = @_;
	my $coupon_code;
	for( my $i=0; $i<3; $i++ ) {
		my $code = Data::Random::String->create_random_string(length=>'8', contains=>'alphanumeric');
		$code = lc $code;
		my $coupon = $self->get_from_db_by_code($code);
		unless($coupon) {
			$coupon_code = $code;
			last;
		}
	}
	return $coupon_code;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#	1.入力データのhashref（必須）
#[戻り値]
#	成功すれば登録データのhashrefを返す。
#	もし存在しないseller_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $coupon_id = $ref->{coupon_id};
	if( ! defined $coupon_id || $coupon_id =~ /[^\d]/) {
		croak "the value of coupon_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#クーポン情報を取得
	my $coupon_old = $self->get_from_db($coupon_id);
	#更新情報をhashrefに格納
	my $rec = {};
	while( my($k, $v) = each %{$ref} ) {
		unless( exists $self->{table_cols}->{$k} ) { next; }
		if($k eq "coupon_id") { next; }
		if( defined $v ) {
			$rec->{$k} = $v;
		} else {
			$rec->{$k} = "";
		}
	}
	#couponsテーブルUPDATE用のSQL生成
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
	my $sql = "UPDATE coupons SET " . join(",", @sets) . " WHERE coupon_id=${coupon_id}";
	#UPDATE
	my $updated;
	eval {
		$updated = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to update a coupon record in coupons table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($updated == 0) {
		return undef;
	}
	#クーポン情報を取得
	my $coupon_new = $self->get_from_db($coupon_id);
	#
	return $coupon_new;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないseller_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $coupon_id) = @_;
	#識別IDのチェック
	if( ! defined $coupon_id || $coupon_id =~ /[^\d]/) {
		croak "the value of coupon_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#クーポン情報を取得
	my $coupon = $self->get_from_db($coupon_id);
	#SQL生成
	my $sql = "DELETE FROM coupons WHERE coupon_id=${coupon_id}";
	#UPDATE
	my $deleted;
	eval {
		$deleted = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a coupon record in coupons table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $coupon;
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
	my($self, $coupon_id) = @_;
	my $ref = $self->get_from_db($coupon_id);
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
	my($self, $coupon_id) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_coupon_id = $dbh->quote($coupon_id);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM coupons WHERE coupon_id=${q_coupon_id}");
	#
	if($ref) {
		my $available = $self->is_available($ref);
		$ref->{coupon_available} = $available;
	}
	#
	return $ref;
}

#---------------------------------------------------------------------
#■クーポンコードからDBレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.クーポンコード（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get_from_db_by_code {
	my($self, $coupon_code) = @_;
	if( ! defined $coupon_code || $coupon_code eq "" ) {
		croak "the 1st argument is invaiid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_coupon_code = $dbh->quote($coupon_code);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM coupons WHERE coupon_code=${q_coupon_code}");
	#
	if($ref) {
		my $available = $self->is_available($ref);
		$ref->{coupon_available} = $available;
	}
	#
	return $ref;
}

#---------------------------------------------------------------------
#■登録されている会員数を取得
#---------------------------------------------------------------------
#[引数]
#	1.識別IDのarrayref（必須）
#[戻り値]
#	識別IDごとの会員数をセットしたhashref
#---------------------------------------------------------------------
sub count_member_num {
	my($self, $arrayref) = @_;
	if( ! defined $arrayref || ref($arrayref) ne "ARRAY" || @{$arrayref} == 0 ) {
		croak "the 1st argument is invaiid.";
	}
	my @coupon_id_list;
	for my $id (@{$arrayref}) {
		if($id =~ /[^\d]/) {
			croak "the 1st argument is invaiid.";
		}
		push(@coupon_id_list, $id);
	}
	my $coupon_id_in = join(",", @coupon_id_list);
	my $sql = "SELECT coupon_id, COUNT(member_id) FROM coupons GROUP BY coupon_id HAVING coupon_id IN (${coupon_id_in})";
	my $dbh = $self->{db}->connect_db();
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my %hash;
	while( my($coupon_id, $count) = $sth->fetchrow_array ) {
		$count += 0;
		$hash{$coupon_id} = $count;
	}
	$sth->finish();
	#
	for my $id (@{$arrayref}) {
		if( ! exists $hash{$id} ) {
			$hash{$id} = 0;
		}
	}
	#
	return \%hash;
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			coupon_id => クーポン識別ID,
#			seller_id => 代理店識別ID,
#			coupon_code => クーポンコード,
#			coupon_available => 有効フラグ,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['coupon_id', "DESC"] ]
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
	my @param_key_list = ('coupon_id', 'seller_id', 'coupon_code', 'coupon_available', 'sort', 'charcode', 'returncode');
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		sort =>[ ['coupon_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "coupon_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "seller_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "coupon_available") {
			if($v !~ /^(0|1)$/) {
				delete $params->{$k};
			}
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(coupon_id)$/) { croak "the value of sort in parameters is invalid."; }
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
	my @col_epoch_index_list;
	for( my $i=0; $i<@{$self->{csv_cols}}; $i++ ) {
		my $r = $self->{csv_cols}->[$i];
		push(@col_list, $r->[0]);
		push(@col_name_list, $r->[1]);
		if($r->[2]) {
			push(@col_epoch_index_list, $i);
		}
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
	if(defined $params->{coupon_id}) {
		push(@wheres, "coupon_id=$params->{coupon_id}");
	}
	if(defined $params->{seller_id}) {
		push(@wheres, "seller_id=$params->{seller_id}");
	}
	if(defined $params->{coupon_code}) {
		my $q_v = $dbh->quote($params->{coupon_code});
		push(@wheres, "coupon_code=${q_v}");
	}
	if(defined $params->{coupon_available}) {
		my $today = $self->{today};
		if($params->{coupon_available}) {
			push(@wheres, "coupon_status=1");
			push(@wheres, "coupon_expire>=${today}");
		} else {
			push(@wheres, "coupon_status=0 OR coupon_expire<${today}");
		}
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM coupons";
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
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_arrayref ) {
			for my $idx (@col_epoch_index_list) {
				if($ref->[$idx]) {
					my @tm = FCC::Class::Date::Utils->new(time=>$ref->[$idx], tz=>$self->{conf}->{tz})->get(1);
					$ref->[$idx] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
				} else {
					$ref->[$idx] = "";
				}
			}
			for( my $i=0; $i<@{$ref}; $i++ ) {
				my $v = $ref->[$i];
				if( ! defined $v ) {
					$ref->[$i] = "";
				} elsif($v =~ /^\-(\d+)$/) {
					$ref->[$i] = $1;
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
#			coupon_id => クーポン識別ID,
#			seller_id => 代理店識別ID,
#			coupon_code => クーポンコード,
#			coupon_available => 有効フラグ,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['coupon_id', "DESC"] ]
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
	my @param_key_list = ('coupon_id', 'seller_id', 'coupon_code', 'coupon_available', 'offset', 'limit', 'sort');
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
		sort =>[ ['coupon_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "coupon_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "seller_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "coupon_available") {
			if($v !~ /^(0|1)$/) {
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
				if($key !~ /^(coupon_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{coupon_id}) {
		push(@wheres, "coupon_id=$params->{coupon_id}");
	}
	if(defined $params->{seller_id}) {
		push(@wheres, "seller_id=$params->{seller_id}");
	}
	if(defined $params->{coupon_code}) {
		my $q_v = $dbh->quote($params->{coupon_code});
		push(@wheres, "coupon_code=${q_v}");
	}
	if(defined $params->{coupon_available}) {
		my $today = $self->{today};
		if($params->{coupon_available}) {
			push(@wheres, "coupon_status=1");
			push(@wheres, "coupon_expire>=${today}");
		} else {
			push(@wheres, "coupon_status=0 OR coupon_expire<${today}");
		}
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(coupon_id) FROM coupons";
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
		my $sql = "SELECT * FROM coupons";
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
			my $available = $self->is_available($ref);
			$ref->{coupon_available} = $available;
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
