package FCC::Class::Dwnsel;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Image::Magick;
use Unicode::Japanese;
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
	#dwnselsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		dsl_id     => "識別ID",
		dwn_id     => "ダウンロード商品識別ID",
		member_id  => "購入会員識別ID",
		dsl_expire => "ダウンロード有効期限",
		dsl_cdate  => "購入日時",
		dsl_point  => "課金ポイント額",
		dsl_type   => "商品種別"
	};
	#CSVの各カラム名と名称とepoch秒フラグ（dsl_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		['dwnsels.dsl_id',     "DL購入識別ID"],
		['dwnsels.dwn_id',     "ダウンロード商品識別ID"],
		['dwns.dwn_title',     "ダウンロード商品名"],
		['dwnsels.member_id',  "購入会員識別ID"],
		['dwnsels.dsl_expire', "ダウンロード有効期限", 1],
		['dwnsels.dsl_cdate',  "購入日時", 1],
		['dwnsels.dsl_point',  "課金ポイント額"],
		['dwnsels.dsl_type',   "商品種別"],
	];
}

#---------------------------------------------------------------------
#■購入数
#---------------------------------------------------------------------
#[引数]
#	1: dwn_id
#[戻り値]
#	購入数
#---------------------------------------------------------------------
sub get_dwn_num {
	my($self, $dwn_id) = @_;
	if( ! $dwn_id || $dwn_id =~ /[^\d]/ ) {
		croak "invalid dwn_id.";
	}
	my $dbh = $self->{db}->connect_db();
	my $sql = "SELECT COUNT(dsl_id) FROM dwnsels WHERE dwn_id=${dwn_id}";
	my($num) = $dbh->selectrow_array($sql);
	return $num;
}

#---------------------------------------------------------------------
#■購入手続き
#---------------------------------------------------------------------
#[引数]
#	1: hashref
#[戻り値]
#	登録したhashref
#---------------------------------------------------------------------
sub add {
	my($self, $ref) = @_;
	my $member_id = $ref->{member_id};
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "invalid member_id.";
	}
	my $seller_id = $ref->{seller_id};
	if( ! $seller_id || $seller_id =~ /[^\d]/ ) {
		croak "invalid seller_id.";
	}
	my $dwn_id = $ref->{dwn_id};
	if( ! $dwn_id || $dwn_id =~ /[^\d]/ ) {
		croak "invalid dwn_id.";
	}
	my $dsl_expire = $ref->{dsl_expire};
	if( ! $dsl_expire || $dsl_expire =~ /[^\d]/ ) {
		croak "invalid dsl_expire.";
	}
	my $dsl_point = $ref->{dsl_point};
	if( $dsl_point eq "" || $dsl_point =~ /[^\d]/ ) {
		croak "invalid dsl_point.";
	}
	my $dsl_type = $ref->{dsl_type};
	if( ! $dsl_type || $dsl_type =~ /[^\d]/ ) {
		croak "invalid dsl_type.";
	}
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
	$rec->{dsl_cdate} = $now;
	#INSERT
	my $dsl_id;
	my $last_sql;
	eval {
		$last_sql = $self->make_insert_sql($dbh, "dwnsels", $rec);
		$dbh->do($last_sql);
		$dsl_id = $dbh->{mysql_insertid};
		#
		my $rec_mbracts = {
			member_id     => $member_id,
			seller_id     => $seller_id,
			mbract_type   => 2,
			mbract_reason => 53,
			mbract_cdate  => $now,
			mbract_price  => $ref->{dsl_point},
			dsl_id        => $dsl_id
		};
		$last_sql = $self->make_insert_sql($dbh, "mbracts", $rec_mbracts);
		$dbh->do($last_sql);
		#
		my $dsl_point = $rec->{dsl_point};
		if($dsl_point > 0) {
			$last_sql = "UPDATE members SET member_point=member_point-${dsl_point} WHERE member_id=${member_id}";
			$dbh->do($last_sql);
		}
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to dwnsels table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#情報を取得
	my $dsl = $self->get($dsl_id);
	#
	return $dsl;
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
#■識別IDからレコード取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $dsl_id) = @_;
	if( ! $dsl_id || $dsl_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT dwnsels.*, dwns.* FROM dwnsels";
	$sql .= " LEFT JOIN dwns ON dwnsels.dwn_id=dwns.dwn_id";
	$sql .= " WHERE dwnsels.dsl_id=${dsl_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■商品識別IDと会員識別IDから直近の購入レコード取得
#---------------------------------------------------------------------
#[引数]
#	1:商品識別ID
#	1:会員識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get_latest_from_dwn_member_id {
	my($self, $dwn_id, $member_id) = @_;
	if( ! $dwn_id || $dwn_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT dwnsels.*, dwns.* FROM dwnsels";
	$sql .= " LEFT JOIN dwns ON dwnsels.dwn_id=dwns.dwn_id";
	$sql .= " WHERE dwnsels.dwn_id=${dwn_id} AND dwnsels.member_id=${member_id}";
	$sql .= " ORDER BY dwnsels.dsl_id DESC LIMIT 0, 1";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_info($ref);
	}
	return $ref;
}


#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			dsl_id => 識別ID,
#			dwn_id => ウンロード商品識別ID,
#			member_id => 会員識別ID,
#			dsl_type => 商品種別,
#			dsl_cdate_s => 検索開始日（YYYYMMDD）,
#			dsl_cdate_e => 検索終了日（YYYYMMDD）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['dsl_id', "DESC"] ]
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
	my($self, $in_params, $calc_flag) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'dsl_id',
		'dwn_id',
		'member_id',
		'dsl_type',
		'dsl_cdate_s',
		'dsl_cdate_e',
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
		sort =>[ ['dsl_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "dsl_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dwn_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dsl_type") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k =~ /^dsl_cdate_[se]$/) {
			if($v !~ /^\d{8}$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(dsl_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
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
	if(defined $params->{dsl_id}) {
		push(@wheres, "dwnsels.dsl_id=$params->{dsl_id}");
	}
	if(defined $params->{dwn_id}) {
		push(@wheres, "dwnsels.dwn_id=$params->{dwn_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "dwnsels.member_id=$params->{member_id}");
	}
	if(defined $params->{dsl_cdate_s}) {
		my($Y, $M, $D) = $params->{dsl_cdate_s} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $epoch = FCC::Class::Date::Utils->new(iso=>"${Y}-${M}-${D} 00:00:00", tz=>$self->{conf}->{tz})->epoch();
		push(@wheres, "dwnsels.dsl_cdate >= ${epoch}");
	}
	if(defined $params->{dsl_cdate_e}) {
		my($Y, $M, $D) = $params->{dsl_cdate_e} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $epoch = FCC::Class::Date::Utils->new(iso=>"${Y}-${M}-${D} 23:59:59", tz=>$self->{conf}->{tz})->epoch();
		push(@wheres, "dwnsels.dsl_cdate <= ${epoch}");
	}
	if(defined $params->{dsl_type}) {
		push(@wheres, "dwnsels.dsl_type=$params->{dsl_type}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM dwnsels";
		$sql .= " LEFT JOIN dwns ON dwnsels.dwn_id=dwns.dwn_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "dwnsels.$ary->[0] $ary->[1]");
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
#			dsl_id => 識別ID,
#			dwn_id => ウンロード商品識別ID,
#			member_id => 会員識別ID,
#			dsl_type => 商品種別,
#			dsl_cdate_s => 検索開始日（YYYYMMDD）,
#			dsl_cdate_e => 検索終了日（YYYYMMDD）,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['dsl_id', "DESC"] ]
#		}
#	2.合計ポイント算出フラグ
#
#[戻り値]
#	検索結果を格納したhashref
#		{
#			list => 各レコードを格納したhashrefのarrayref,
#			hit => 検索ヒット数,
#			fetch => フェッチしたレコード数,
#			start => 取り出したレコードの開始番号（offset+1, ただしhit=0の場合はstartも0となる）,
#			end => 取り出したレコードの終了番号（offset+fetch, ただしhit=0の場合はendも0となる）,
#			params => 検索条件を格納したhashref,
#			total_sale => 合計ポイント（第二引数に1がセットされた場合のみ）
#		}
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_list {
	my($self, $in_params, $calc_flag) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'dsl_id',
		'dwn_id',
		'member_id',
		'dsl_type',
		'dsl_cdate_s',
		'dsl_cdate_e',
		'offset',
		'limit',
		'sort'
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
		sort =>[ ['dsl_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "dsl_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dwn_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "dsl_type") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k =~ /^dsl_cdate_[se]$/) {
			if($v !~ /^\d{8}$/) {
				croak "the value of ${k} in parameters is invalid.";
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
				if($key !~ /^(dsl_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{dsl_id}) {
		push(@wheres, "dwnsels.dsl_id=$params->{dsl_id}");
	}
	if(defined $params->{dwn_id}) {
		push(@wheres, "dwnsels.dwn_id=$params->{dwn_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "dwnsels.member_id=$params->{member_id}");
	}
	if(defined $params->{dsl_cdate_s}) {
		my($Y, $M, $D) = $params->{dsl_cdate_s} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $epoch = FCC::Class::Date::Utils->new(iso=>"${Y}-${M}-${D} 00:00:00", tz=>$self->{conf}->{tz})->epoch();
		push(@wheres, "dwnsels.dsl_cdate >= ${epoch}");
	}
	if(defined $params->{dsl_cdate_e}) {
		my($Y, $M, $D) = $params->{dsl_cdate_e} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $epoch = FCC::Class::Date::Utils->new(iso=>"${Y}-${M}-${D} 23:59:59", tz=>$self->{conf}->{tz})->epoch();
		push(@wheres, "dwnsels.dsl_cdate <= ${epoch}");
	}
	if(defined $params->{dsl_type}) {
		push(@wheres, "dwnsels.dsl_type=$params->{dsl_type}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(dsl_id) FROM dwnsels";
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
		my $sql = "SELECT dwnsels.*, dwns.* FROM dwnsels";
		$sql .= " LEFT JOIN dwns ON dwnsels.dwn_id=dwns.dwn_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "dwnsels.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			$self->add_info($ref);
			push(@list, $ref);
		}
		$sth->finish();
	}
	#合計ポイント算出
	my $total_sale = 0;
	if( $calc_flag ) {
		my $sql = "SELECT SUM(dsl_point) FROM dwnsels";
		if(@wheres) {
			$sql .= " WHERE ";
			$sql .= join(" AND ", @wheres);
		}
		($total_sale) = $dbh->selectrow_array($sql);
	}
	$total_sale += 0;
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
	$res->{total_sale} = $total_sale;
	#
	return $res;
}

sub add_info {
	my($self, $ref) = @_;
	my $now = time;
	if($now <= $ref->{dsl_expire}) {
		$ref->{dsl_qualified} = 1;
	} else {
		$ref->{dsl_qualified} = 0;
	}
	#
	for my $col ("dsl_expire", "dsl_cdate", "dwn_pubdate") {
		my $v = $ref->{$col};
		unless($v) { next; }
		my %fmt = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get_formated();
		while( my($k, $v) = each %fmt ) {
			$ref->{"${col}_${k}"} = $v;
		}
	}
}

1;
