package FCC::Class::Sdm;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Date::Pcalc;
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
	#sdmsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		sdm_id     => "識別ID",
		seller_id  => "代理店識別ID",
		sdm_cdate  => "請求日時",
		sdm_status => "支払ステータス",
		sdm_price  => "請求金額"
	};
	#CSVの各カラム名と名称とepoch秒フラグ（sdm_idは必ず0番目にセットすること）
	$self->{csv_cols} = [
		["sdms.sdm_id",            "代理店請求依頼識別ID"],
		["sdms.seller_id",         "代理店識別ID"],
		["sellers.seller_company", "会社名"],
		["sdms.sdm_cdate",         "請求日時", 1],
		["sdms.sdm_status",        "支払ステータス", 0, {"1" => "支払中", "2" => "支払済み"}],
		["sdms.sdm_price",         "請求金額"]
	];
	#
	my @country_lines = split(/\n+/, $self->{conf}->{prof_countries});
	$self->{prof_country_hash} = {};
	$self->{prof_country_list} = [];
	for my $line (@country_lines) {
		if( $line =~ /^([a-z]{2})\s+(.+)/ ) {
			my $code = $1;
			my $name = $2;
			$self->{prof_country_hash}->{$code} = $name;
			push(@{$self->{prof_country_list}}, [$code, $name]);
		}
	}
	#レッスンのCSVの各カラム名と名称とepoch秒フラグ（lsn_idは必ず0番目にセットすること）
	$self->{lsn_csv_cols} = [
		['lessons.lsn_id',         "レッスン識別ID"],
		['lessons.lsn_sdm_status', "状態"],
		['lessons.lsn_stime',      "開始日時"],
		['lessons.lsn_etime',      "終了日時"],
		['profs.prof_handle',      $self->{conf}->{prof_handle_caption}],
		['members.member_handle',  $self->{conf}->{member_handle_caption}],
		['lessons.lsn_status',     "ステータス"],
		['lessons.lsn_seller_price', "ポイント"]
	];
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
	my($self, $sdm_id) = @_;
	if( ! $sdm_id || $sdm_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT sdms.*, sellers.* FROM sdms";
	$sql .= " LEFT JOIN sellers ON sdms.seller_id=sellers.seller_id";
	$sql .= " WHERE sdms.sdm_id=${sdm_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_datetime_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■ステータスを更新（管理者用）
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#	2:ステータス値
#[戻り値]
#	該当のレコードのhashref
#---------------------------------------------------------------------
sub set_sdm_status {
	my($self, $sdm_id, $sdm_status) = @_;
	if( ! $sdm_id || $sdm_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	if( $sdm_status !~ /^(0|1|2)$/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#アップデート
	my $last_sql;
	my $updated = 0;
	eval {
		$last_sql = "UPDATE sdms SET sdm_status=${sdm_status} WHERE sdm_id=${sdm_id}";
		$updated = $dbh->do($last_sql);
		if($updated) {
			$last_sql = "UPDATE lessons SET lsn_sdm_status=${sdm_status} WHERE sdm_id=${sdm_id}";
			$dbh->do($last_sql);
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to update a sdm record in sdms table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#
	my $sdm = $self->get($sdm_id);
	return $sdm;
}


#---------------------------------------------------------------------
#■代理店が請求可能なレッスンIDのリストと合計額を算出
#---------------------------------------------------------------------
#[引数]
#	1:代理店識別ID
#[戻り値]
#	{
#		lsn_id_list => lsn_idのarrayref,
#		lsn_list    => レッスン情報のarrayref,
#		price       => 合計額,
#		demand_flag => 最低請求額を満たしているかを表すフラグ（0:満たしていない、1:満たしている）
#	}
#---------------------------------------------------------------------
sub get_demand_target {
	my($self, $seller_id) = @_;
	if( ! $seller_id || $seller_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#請求可能日付の確定
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get();
	my($y, $m, $d) = Date::Pcalc::Add_Delta_Days($tm[0], $tm[1], $tm[2], 0-$self->{conf}->{sdm_limit});
	my $limit_datetime = $y . "-" . sprintf("%02d", $m) . "-" . sprintf("%02d", $d) . " 00:00:00";
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my $sql = "SELECT lessons.*, members.member_handle, profs.prof_handle FROM lessons";
	$sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
	$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
	$sql .= " WHERE lessons.seller_id=${seller_id} AND lessons.sdm_id=0 AND lessons.lsn_etime>='${limit_datetime}' AND lessons.lsn_charged_date>0 AND lessons.lsn_seller_price>0";
	$sql .= " ORDER BY lessons.lsn_stime ASC";
	$sql .= " LIMIT 0, 100";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my $sdm_price = 0;
	my $lsn_id_list = [];
	my $lsn_list = [];
	while( my $ref = $sth->fetchrow_hashref ) {
		$self->add_datetime_info($ref);
		push(@{$lsn_id_list}, $ref->{lsn_id});
		push(@{$lsn_list}, $ref);
		$sdm_price += $ref->{lsn_seller_price};
	}
	$sth->finish();
	#
	my $res = {
		lsn_id_list   => $lsn_id_list,
		lsn_list      => $lsn_list,
		sdm_price     => $sdm_price,
		sdm_demand_ok => ($sdm_price >= $self->{conf}->{sdm_min_price}) ? 1 : 0
	};
	return $res;
}

#---------------------------------------------------------------------
#■請求申請（代理店からの申請）
#---------------------------------------------------------------------
#[引数]
#	1: 代理店識別ID,
#	2: demand_targetのhashref
#	{
#		lsn_id_list => lsn_idのarrayref,
#		sdm_price   => 合計額
#	}
#	※ lsn_list, sdm_demand_ok は不要
#[戻り値]
#	登録したhashref
#---------------------------------------------------------------------
sub add {
	my($self, $seller_id, $demand_target) = @_;
	#
	my $sdm_price = $demand_target->{sdm_price};
	my $lsn_id_list = $demand_target->{lsn_id_list};
	#
	if( $sdm_price =~ /[^\d]/ || $sdm_price == 0 ) {
		croak "a parameter is invalid.";
	}
	if( ref($lsn_id_list) ne "ARRAY" || ! @{$lsn_id_list} ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my $rec = {
		seller_id => $seller_id,
		sdm_cdate  => time,
		sdm_status => 1,
		sdm_price  => $sdm_price
	};
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
	my $sdm_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO sdms (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$sdm_id = $dbh->{mysql_insertid};
		for my $lsn_id (@{$lsn_id_list}) {
			$last_sql = "UPDATE lessons SET sdm_id=${sdm_id}, lsn_sdm_status=1 WHERE lsn_id=${lsn_id}";
			$dbh->do($last_sql);
		}
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to sdms table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#情報を取得
	my $sdm = $self->get($sdm_id);
	#
	return $sdm;
}

#---------------------------------------------------------------------
#■請求対象のレッスン一覧をCSVで取得（代理店メニューで利用）
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			seller_id => 代理店識別ID,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['lsn_stime', "DESC"] ]
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
sub get_lsn_csv {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'seller_id',
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
		sort =>[ ['lsn_stime', "ASC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(seller)_id$/) {
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
				if($key !~ /^(lsn_id|lsn_stime)$/) { croak "the value of sort in parameters is invalid."; }
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
	#請求可能日付の確定
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get();
	my($y, $m, $d) = Date::Pcalc::Add_Delta_Days($tm[0], $tm[1], $tm[2], 0-$self->{conf}->{sdm_limit});
	my $limit_datetime = $y . "-" . sprintf("%02d", $m) . "-" . sprintf("%02d", $d) . " 00:00:00";
	#カラムの一覧
	my @col_list;
	my @col_name_list;
	my @col_epoch_index_list;
	for( my $i=0; $i<@{$self->{lsn_csv_cols}}; $i++ ) {
		my $r = $self->{lsn_csv_cols}->[$i];
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
	if(defined $params->{seller_id}) {
		push(@wheres, "lessons.seller_id=$params->{seller_id}");
	}
	push(@wheres, "lessons.lsn_seller_price>0");
	push(@wheres, "lessons.lsn_charged_date>0");
	push(@wheres, "lessons.lsn_etime>='${limit_datetime}'");
	#SELECT
	my $lsn_sdm_status_names = {
		0 => "未請求",
		1 => "支払中",
		2 => "支払済み"
	};
	my $lsn_status_names = {
		1 => "完了",
		11 => "$self->{conf}->{member_caption}通常キャンセル",
		12 => "$self->{conf}->{member_caption}緊急キャンセル",
		13 => "$self->{conf}->{member_caption}放置キャンセル",
		21 => "$self->{conf}->{prof_caption}通常キャンセル",
		22 => "$self->{conf}->{prof_caption}緊急キャンセル",
		23 => "$self->{conf}->{prof_caption}放置キャンセル",
		29 => "その他理由による非課金"
	};
	#
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM lessons";
		$sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
		$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "lessons.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_arrayref ) {
			for( my $i=0; $i<@{$ref}; $i++ ) {
				my $k = $col_list[$i];
				my $v = $ref->[$i];
				if( ! defined $v ) { $ref->[$i] = ""; }
				if($k =~ /\.lsn_sdm_status$/) {
					$ref->[$i] = $lsn_sdm_status_names->{$v};
				} elsif($k =~ /\.lsn_status$/) {
					$ref->[$i] = $lsn_status_names->{$v};
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
#■請求対象のレッスン一覧を取得（講師メニュー、管理者メニューで利用）
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			seller_id => 代理店識別ID,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['lsn_stime', "DESC"] ]
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
sub get_lsn_list {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'seller_id',
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
		sort =>[ ['lsn_stime', "ASC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(seller)_id$/) {
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
				if($key !~ /^(lsn_id|lsn_stime)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#請求可能日付の確定
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get();
	my($y, $m, $d) = Date::Pcalc::Add_Delta_Days($tm[0], $tm[1], $tm[2], 0-$self->{conf}->{sdm_limit});
	my $limit_datetime = $y . "-" . sprintf("%02d", $m) . "-" . sprintf("%02d", $d) . " 00:00:00";
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{seller_id}) {
		push(@wheres, "lessons.seller_id=$params->{seller_id}");
	}
	push(@wheres, "lessons.lsn_seller_price>0");
	push(@wheres, "lessons.lsn_charged_date>0");
	push(@wheres, "lessons.lsn_etime>='${limit_datetime}'");
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(lessons.lsn_id) FROM lessons";
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
		my $sql = "SELECT lessons.*, profs.prof_handle, members.member_handle FROM lessons";
		$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
		$sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "lessons.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			$self->add_datetime_info($ref);
			$self->add_prof_info($ref);
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

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			sdm_id => 識別ID,
#			seller_id => 代理店識別ID,
#			sdm_status => ステータス,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#			charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#			returncode => 改行コード（指定がなければLF）
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			sort =>[ ['sdm_id', "DESC"] ]
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
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'sdm_id',
		'seller_id',
		'sdm_status',
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
		sort =>[ ['sdm_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(sdm|seller)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "sdm_status") {
			if($v =~ /[^\d]/) {
				croak "the value of sdm_status in parameters is invalid.";
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
				if($key !~ /^(sdm_id)$/) { croak "the value of sort in parameters is invalid."; }
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
	if(defined $params->{sdm_id}) {
		push(@wheres, "sdms.sdm_id=$params->{sdm_id}");
	}
	if(defined $params->{seller_id}) {
		push(@wheres, "sdms.seller_id=$params->{seller_id}");
	}
	if(defined $params->{sdm_status}) {
		push(@wheres, "sdms.sdm_status=$params->{sdm_status}");
	}
	#SELECT
	my @list;
	{
		my $sql = "SELECT " . join(",", @col_list) . " FROM sdms";
		$sql .= " LEFT JOIN sellers ON sdms.seller_id=sellers.seller_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "sdms.$ary->[0] $ary->[1]");
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

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			sdm_id => 識別ID,
#			seller_id => 代理店識別ID,
#			sdm_status => ステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['sdm_id', "DESC"] ]
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
		'sdm_id',
		'seller_id',
		'sdm_status',
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
		sort =>[ ['sdm_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(sdm|seller)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "sdm_status") {
			if($v =~ /[^\d]/) {
				croak "the value of sdm_status in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
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
				if($key !~ /^(sdm_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{sdm_id}) {
		push(@wheres, "sdms.sdm_id=$params->{sdm_id}");
	}
	if(defined $params->{seller_id}) {
		push(@wheres, "sdms.seller_id=$params->{seller_id}");
	}
	if(defined $params->{sdm_status}) {
		push(@wheres, "sdms.sdm_status=$params->{sdm_status}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(sdm_id) FROM sdms";
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
		my $sql = "SELECT sdms.*, sellers.* FROM sdms";
		$sql .= " LEFT JOIN sellers ON sdms.seller_id=sellers.seller_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "sdms.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			$self->add_datetime_info($ref);
			$self->add_prof_info($ref);
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

sub add_prof_info {
	my($self, $ref) = @_;
	$ref->{prof_country_name} = $self->{prof_country_hash}->{$ref->{prof_country}};
	$ref->{prof_residence_name} = $self->{prof_country_hash}->{$ref->{prof_residence}};
	my $prof_id = $ref->{prof_id};
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
		$ref->{"prof_logo_${s}_w"} = $self->{conf}->{"prof_logo_${s}_w"};
		$ref->{"prof_logo_${s}_h"} = $self->{conf}->{"prof_logo_${s}_h"};
	}
}

sub add_datetime_info {
	my($self, $ref) = @_;
	my %sdm_cdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{sdm_cdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %sdm_cdate_fmt ) {
		$ref->{"sdm_cdate_${k}"} = $v;
	}
	if($ref->{lsn_stime} && $ref->{lsn_etime}) {
		my($sY, $sM, $sD, $sh, $sm) = $ref->{lsn_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
		my($eY, $eM, $eD, $eh, $em) = $ref->{lsn_etime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
		$ref->{stime} = ($sh + 0) . ":" . $sm;
		$ref->{etime} = ($eh + 0) . ":" . $em;
		#レッスン開始日時
		my $stime_epoch = FCC::Class::Date::Utils->new(iso=>"${sY}-${sM}-${sD} ${sh}:${sm}:00", tz=>$self->{conf}->{tz})->epoch();
		my %stime_fmt = FCC::Class::Date::Utils->new(time=>$stime_epoch, tz=>$self->{conf}->{tz})->get_formated();
		while( my($k, $v) = each %stime_fmt ) {
			$ref->{"lsn_stime_${k}"} = $v;
		}
		#レッスン修了日時
		my $etime_epoch = FCC::Class::Date::Utils->new(iso=>"${eY}-${eM}-${eD} ${eh}:${em}:00", tz=>$self->{conf}->{tz})->epoch();
		my %etime_fmt = FCC::Class::Date::Utils->new(time=>$etime_epoch, tz=>$self->{conf}->{tz})->get_formated();
		while( my($k, $v) = each %etime_fmt ) {
			$ref->{"lsn_etime_${k}"} = $v;
		}
	}
}

1;
