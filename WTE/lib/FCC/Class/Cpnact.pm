package FCC::Class::Cpnact;
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
}

#---------------------------------------------------------------------
#■クーポンをチャージ（入金および出金）
#---------------------------------------------------------------------
#[引数]
#	パラメータを格納したhashref
#	{
#		coupon_id => クーポン識別ID（必須）
#		member_id => 会員識別ID（必須）,
#		seller_id => 代理店識別ID（必須）,
#		cpnact_type => 入出金種別（1:入金、2:出金）,
#		cpnact_reason => 入出金摘要,
#		cpnact_price => 金額（出金でもマイナスの値にしないこと）
#	}
#	※クーポン受領処理や会員の商品注文による入出金については、本メソッドは利用できない。
#	※cpnacts_reasonは以下の値
#		11：入金（会員登録）
#		12：入金（管理者から付与）
#		51：出金（商品注文）
#		52：出金（管理者による減算）
#		91：出金（有効期限切れ）
#
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub charge {
	my($self, $p) = @_;
	#入力値をチェック
	if( ! $p || ref($p) ne "HASH" ) {
		croak "the 1st augument must be a hashref.";
	}
	if( ! defined $p->{coupon_id} ||  $p->{coupon_id} eq "" || $p->{coupon_id} =~ /[^\d]/ ) {
		croak "coupon_id is invalid.";
	}
	if( ! $p->{member_id} || $p->{member_id} =~ /[^\d]/ ) {
		croak "member_id is invalid.";
	}
	if( ! $p->{seller_id} || $p->{seller_id} =~ /[^\d]/ ) {
		croak "seller_id is invalid.";
	}
	if( ! $p->{cpnact_type} || $p->{cpnact_type} !~ /^(1|2)$/ ) {
		croak "cpnact_type is invalid.";
	}
	if( ! $p->{cpnact_reason} || $p->{cpnact_reason} !~ /^\d{2}$/ ) {
		croak "cpnact_reason is invalid.";
	}
	if( ! $p->{cpnact_price} || $p->{cpnact_price} =~ /[^\d]/ ) {
		croak "cpnact_price is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#membersテーブルのレコード更新SQL
	my $sign = "+";
	if($p->{cpnact_type} == 2) {
		$sign = "-";
	}
	my $sql1 = "UPDATE members SET member_coupon=member_coupon${sign}$p->{cpnact_price} WHERE member_id=$p->{member_id}";
	#cpnactsテーブルへのレコード追加SQL
	my $now = time;
	my $price = $p->{cpnact_price};
	if($p->{cpnact_type} == 2) {
		$price = 0 - $price;
	}
	my $rec = {
		coupon_id => $p->{coupon_id},
		seller_id => $p->{seller_id},
		member_id => $p->{member_id},
		cpnact_type => $p->{cpnact_type},
		cpnact_reason => $p->{cpnact_reason},
		cpnact_cdate => $now,
		cpnact_price => $price
	};
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		push(@vlist, $v);
	}
	my $sql2 = "INSERT INTO cpnacts (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
	#SQL実行
	my $last_sql;
	my $cpnact_id;
	eval {
		$last_sql = $sql1;
		my $updated = $dbh->do($sql1);
		if($updated == 0) {
			die "the specified member_id is not found.";
		}
		$cpnact_id = $dbh->{mysql_insertid};
		$last_sql = $sql2;
		$dbh->do($sql2);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "$@ : ${last_sql}");
		croak $@;
	}
	#
	$rec->{cpnact_id} = $cpnact_id;
	return $rec;
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#---------------------------------------------------------------------
sub get {
	my($self, $cpnact_id) = @_;
	if( ! $cpnact_id || $cpnact_id =~ /[^\d]/ ) {
		croak "invalid parameter.";
	}
	my $dbh = $self->{db}->connect_db();
	my $sql = "SELECT cpnacts.*, sellers.*, members.* FROM cpnacts";
	$sql .= " LEFT JOIN sellers ON cpnacts.seller_id=cpnacts.seller_id";
	$sql .= " LEFT JOIN members ON members.member_id=cpnacts.member_id";
	$sql .= " WHERE cpnacts.cpnact_id=${cpnact_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	return $ref;
}

#---------------------------------------------------------------------
#■検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			cpnact_id => 識別ID,
#			coupon_id => クーポン識別ID,
#			member_id => 会員識別ID,
#			cpnact_cdate1 => 開始日時(epoch秒),
#			cpnact_cdate2 => 終了日時(epoch秒),
#			cpnact_reason => 入出金摘要
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['cpnact_id', "DESC"] ]
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
		'cpnact_id',
		'coupon_id',
		'member_id',
		'cpnact_cdate1',
		'cpnact_cdate2',
		'cpnact_reason',
		'offset',
		'limit',
		'sort'
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
		sort =>[ ['cpnact_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "cpnact_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "coupon_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "cpnact_cdate1") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "cpnact_cdate2") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "cpnact_reason") {
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
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(cpnact_id|member_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{cpnact_id}) {
		push(@wheres, "cpnacts.cpnact_id=$params->{cpnact_id}");
	}
	if(defined $params->{coupon_id}) {
		my $q_coupon_id = $dbh->quote($params->{coupon_id});
		push(@wheres, "cpnacts.coupon_id=${q_coupon_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "cpnacts.member_id=$params->{member_id}");
	}
	if(defined $params->{cpnact_cdate1}) {
		push(@wheres, "cpnacts.cpnact_cdate>=$params->{cpnact_cdate1}");
	}
	if(defined $params->{cpnact_cdate2}) {
		push(@wheres, "cpnacts.cpnact_cdate<=$params->{cpnact_cdate2}");
	}
	if(defined $params->{cpnact_reason}) {
		push(@wheres, "cpnacts.cpnact_reason=$params->{cpnact_reason}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(cpnacts.cpnact_id) FROM cpnacts";
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
		my $sql = "SELECT cpnacts.*, sellers.*, members.* FROM cpnacts";
		$sql .= " LEFT JOIN sellers ON cpnacts.seller_id=sellers.seller_id";
		$sql .= " LEFT JOIN members ON cpnacts.member_id=members.member_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "cpnacts.$ary->[0] $ary->[1]");
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
