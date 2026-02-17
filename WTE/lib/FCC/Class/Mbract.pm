package FCC::Class::Mbract;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Unicode::Japanese;
use FCC::Class::Log;
use FCC::Class::Date::Utils;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#CSVの各カラム名と名称とepoch秒フラグ（auto_idは必ず0番目にセットすること）
	my $mbract_reason_cap = {
		"11" => "入金（会員登録）",
		"12" => "入金（管理者から付与）",
		"13" => "入金（キャンセルによる払い戻し）",
		"41" => "入金（クレジット単発ポイント購入）",
		"42" => "入金（クレジット月次自動ポイント購入）",
		"43" => "入金（銀行振込単発ポイント購入）",
		"51" => "出金（レッスン費）",
		"52" => "出金（管理者による減算）",
		"53" => "出金（ダウンロード商品費）",
		"91" => "出金（有効期限切れ）"
	};
	$self->{csv_cols} = [
		["mbracts.mbract_id",        "入出金識別ID"],
		["mbracts.member_id",        "$self->{conf}->{member_caption}識別ID"],
		["members.member_lastname",  "姓"],
		["members.member_firstname", "名"],
		["members.member_handle",    "ニックネーム"],
		["mbracts.seller_id",        "代理店識別ID"],
		["sellers.seller_company",   "代理店会社名"],
		["mbracts.mbract_type",      "入出金種別", { "1" => "入金", "2" => "出金" }],
		["mbracts.mbract_reason",    "入出金摘要", 0, $mbract_reason_cap],
		["mbracts.mbract_cdate",     "入出金日時", 1],
		["mbracts.mbract_price",     "金額"],
		["mbracts.crd_id",           "カード決済ID"],
		["mbracts.auto_id",          "自動課金ID"],
		["mbracts.lsn_id",           "注文識別ID"],
		["mbracts.dsl_id",           "ダウンロード商品注文識別ID"]
	];
}


#---------------------------------------------------------------------
#■ポイントをチャージ（入金および出金）
#---------------------------------------------------------------------
#[引数]
#	パラメータを格納したhashref
#	{
#		member_id => 会員識別ID（必須）,
#		seller_id => 代理店識別ID（必須）,
#		mbract_type => 入出金種別（1:入金、2:出金）,
#		mbract_reason => 入出金摘要,
#		mbract_price => 金額（出金でもマイナスの値にしないこと）,
#		crd_id => カード決済識別ID（mbract_reasonが41, 42の場合）,
#		auto_id => 自動課金識別ID（mbract_reasonが41, 42の場合）
#	}
#	※会員の商品注文による出金については、本メソッドは利用できない。
#	※mbract_reasonは以下の値
#	11：入金（会員登録）
#	12：入金（管理者から付与）
#	13：入金（キャンセルによる払い戻し）
#	41：入金（クレジット単発ポイント購入）
#	42：入金（クレジット月次自動ポイント購入）
#	43：入金（銀行振込単発ポイント購入）
#	51：出金（レッスン費）
#	52：出金（管理者による減算）
#	53：出金（ダウンロード商品費）
#	91：出金（有効期限切れ）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub charge {
	my($self, $p) = @_;
	#入力値をチェック
	if( ! $p || ref($p) ne "HASH" ) {
		croak "the 1st augument must be a hashref.";
	}
	if( ! $p->{member_id} || $p->{member_id} =~ /[^\d]/ ) {
		croak "member_id is invalid.";
	}
	if( ! $p->{seller_id} || $p->{seller_id} =~ /[^\d]/ ) {
		croak "seller_id is invalid.";
	}
	if( ! $p->{mbract_type} || $p->{mbract_type} !~ /^(1|2)$/ ) {
		croak "mbract_type is invalid.";
	}
	if( ! $p->{mbract_reason} || $p->{mbract_reason} !~ /^\d{2}$/ ) {
		croak "mbract_reason is invalid.";
	}
#	if( ! $p->{mbract_price} || $p->{mbract_price} =~ /[^\d]/ ) {
	if( $p->{mbract_price} eq "" || $p->{mbract_price} =~ /[^\d]/ ) {
		croak "mbract_price is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#membersテーブルのレコード更新SQL
	my $sign = "+";
	if($p->{mbract_type} == 2) {
		$sign = "-";
	}
	my $sql1 = "UPDATE members SET member_point=member_point${sign}$p->{mbract_price} WHERE member_id=$p->{member_id}";
	#mbractsテーブルへのレコード追加SQL
	my $now = time;
	my $price = $p->{mbract_price};
	if($p->{mbract_type} == 2) {
		$price = 0 - $price;
	}
	my $rec = {
		seller_id => $p->{seller_id},
		member_id => $p->{member_id},
		mbract_type => $p->{mbract_type},
		mbract_reason => $p->{mbract_reason},
		mbract_cdate => $now,
		mbract_price => $price
	};
	if($p->{mbract_reason} =~ /^(41|42)$/) {
		if($p->{crd_id}) {
			$rec->{crd_id} = $p->{crd_id};
		}
		if($p->{auto_id}) {
			$rec->{auto_id} = $p->{auto_id};
		}
	}
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		push(@vlist, $v);
	}
	my $sql2 = "INSERT INTO mbracts (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
	#ポイント有効期限の延長
	my $sql3;
	if($p->{mbract_type} == 1) {
		my $epoch = time + (86400 * $self->{conf}->{point_expire_days});
		my @tm = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
		my $expire_date = $dbh->quote("$tm[0]-$tm[1]-$tm[2]");
		$sql3 = "UPDATE members SET member_point_expire=${expire_date} WHERE member_id=$p->{member_id}";
	}
	#SQL実行
	my $last_sql;
	my $mbract_id;
	eval {
		$last_sql = $sql1;
		my $updated = $dbh->do($sql1);
		if($updated == 0) {
			die "the specified member_id is not found.";
		}
		$mbract_id = $dbh->{mysql_insertid};
		$last_sql = $sql2;
		$dbh->do($sql2);
		if($sql3) {
			$last_sql = $sql3;
			$dbh->do($sql3);
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "$@ : ${last_sql}");
		croak $@;
	}
	#
	$rec->{mbract_id} = $mbract_id;
	return $rec;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.入出金識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get {
	my($self, $mbract_id) = @_;
	if( ! $mbract_id || $mbract_id =~ /[^\d]/ ) {
		croak "invalid parameter.";
	}
	my $dbh = $self->{db}->connect_db();
	my $sql = "SELECT mbracts.*, sellers.*, members.* FROM mbracts";
	$sql .= " LEFT JOIN sellers ON mbracts.seller_id=sellers.seller_id";
	$sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
	$sql .= " WHERE mbracts.mbract_id=${mbract_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	return $ref;
}


#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			mbract_id => 入出金識別ID,
#			member_id => 会員識別ID,
#			mbract_cdate1 => 開始日時(epoch秒),
#			mbract_cdate2 => 終了日時(epoch秒),
#			mbract_reason => 入出金摘要
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['mbract_id', "DESC"] ]
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
		'mbract_id',
		'member_id',
		'mbract_cdate1',
		'mbract_cdate2',
		'mbract_reason',
		'sort',
		'charcode',
		'returncode'
	);
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
		sort =>[ ['mbract_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "mbract_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "mbract_cdate1") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "mbract_cdate2") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "mbract_reason") {
			if($v !~ /^\d{2}$/) {
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
				if($key !~ /^(mbract_id|member_id)$/) { croak "the value of sort in parameters is invalid."; }
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
	if(defined $params->{mbract_id}) {
		push(@wheres, "mbracts.mbract_id=$params->{mbract_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "mbracts.member_id=$params->{member_id}");
	}
	if(defined $params->{mbract_cdate1}) {
		push(@wheres, "mbracts.mbract_cdate>=$params->{mbract_cdate1}");
	}
	if(defined $params->{mbract_cdate2}) {
		push(@wheres, "mbracts.mbract_cdate<=$params->{mbract_cdate2}");
	}
	if(defined $params->{mbract_reason}) {
		push(@wheres, "mbracts.mbract_reason=$params->{mbract_reason}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM mbracts";
		$sql .= " LEFT JOIN sellers ON mbracts.seller_id=sellers.seller_id";
		$sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "mbracts.$ary->[0] $ary->[1]");
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
#■検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			mbract_id => 入出金識別ID,
#			member_id => 会員識別ID,
#			offset => オフセット値（デフォルト値：0）,
#			mbract_cdate1 => 開始日時(epoch秒),
#			mbract_cdate2 => 終了日時(epoch秒),
#			mbract_reason => 入出金摘要
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['mbract_id', "DESC"] ]
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
	my @param_key_list = ('mbract_id', 'member_id', 'mbract_cdate1', 'mbract_cdate2', 'mbract_reason', 'offset', 'limit', 'sort');
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
		sort =>[ ['mbract_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "mbract_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "mbract_cdate1") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "mbract_cdate2") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "mbract_reason") {
			if($v !~ /^\d{2}$/) {
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
			if($params->{$k} > 100) {
				$params->{$k} = 100;
			}
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(mbract_id|member_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{mbract_id}) {
		push(@wheres, "mbracts.mbract_id=$params->{mbract_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "mbracts.member_id=$params->{member_id}");
	}
	if(defined $params->{mbract_cdate1}) {
		push(@wheres, "mbracts.mbract_cdate>=$params->{mbract_cdate1}");
	}
	if(defined $params->{mbract_cdate2}) {
		push(@wheres, "mbracts.mbract_cdate<=$params->{mbract_cdate2}");
	}
	if(defined $params->{mbract_reason}) {
		push(@wheres, "mbracts.mbract_reason=$params->{mbract_reason}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(mbracts.mbract_id) FROM mbracts";
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
		my $sql = "SELECT mbracts.*, sellers.*, members.* FROM mbracts";
		$sql .= " LEFT JOIN sellers ON mbracts.seller_id=sellers.seller_id";
		$sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "mbracts.$ary->[0] $ary->[1]");
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

1;
