package FCC::Class::Fav;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#favsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		fav_id        => "識別ID",
		member_id     => "会員識別ID",
		prof_id       => "講師識別ID",
		fav_cdate     => "登録日時",
		fav_comment   => "コメント"
	};
}

#---------------------------------------------------------------------
#■識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $fav_id) = @_;
	if( ! $fav_id || $fav_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT * FROM favs WHERE fav_id=${fav_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_prof_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■会員識別IDと講師識別IDからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1:会員識別ID
#	2:講師識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get_from_member_prof_id {
	my($self, $member_id, $prof_id) = @_;
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	if( ! $prof_id || $prof_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT * FROM favs WHERE member_id=${member_id} AND prof_id=${prof_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_prof_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■会員識別IDから登録されているお気に入りの数を調べる
#---------------------------------------------------------------------
#[引数]
#	1:会員識別ID
#[戻り値]
#	数値
#---------------------------------------------------------------------
sub get_member_fav_num {
	my($self, $member_id) = @_;
	if( ! $member_id || $member_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT COUNT(fav_id) FROM favs WHERE member_id=${member_id}";
	my($num) = $dbh->selectrow_array($sql);
	return $num + 0;
}

#---------------------------------------------------------------------
#■メッセージ登録
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
	$rec->{fav_cdate} = $now;
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
	my $fav_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO favs (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$fav_id = $dbh->{mysql_insertid};
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to insert a record to favs table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#情報を取得
	my $fav = $self->get($fav_id);
	#
	return $fav;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないfav_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $fav_id) = @_;
	#識別IDのチェック
	if( ! defined $fav_id || $fav_id =~ /[^\d]/) {
		croak "the value of fav_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#データ情報を取得
	my $fav = $self->get($fav_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM favs WHERE fav_id=${fav_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in favs table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $fav;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			fav_id        => お気に入り識別ID,
#			member_id     => 会員識別ID,
#			prof_id       => 講師識別ID,
#			prof_status   => 講師ステータス,
#			offset        => オフセット値（デフォルト値：0）,
#			limit         => リミット値（デフォルト値：20）,
#			sort          => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit  => 20,
#			sort   =>[ ['fav_id', "DESC"] ]
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
		'fav_id',
		'member_id',
		'prof_id',
		'prof_status',
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
		sort =>[ ['fav_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(fav|prof|member)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "prof_status") {
			if($v =~ /^(0|1)$/) {
				$params->{$k} = $v + 0;
			} else {
				delete $params->{$k};
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
				if($key !~ /^(fav_id|member_id|prof_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{fav_id}) {
		push(@wheres, "favs.fav_id=$params->{fav_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "favs.member_id=$params->{member_id}");
	}
	if(defined $params->{prof_id}) {
		push(@wheres, "favs.prof_id=$params->{prof_id}");
	}
	if(defined $params->{prof_status}) {
		push(@wheres, "profs.prof_status=$params->{prof_status}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(favs.fav_id) FROM favs LEFT JOIN profs ON favs.prof_id=profs.prof_id";
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
		my $sql = "SELECT favs.*, profs.* FROM favs LEFT JOIN profs ON favs.prof_id=profs.prof_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "favs.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
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

#---------------------------------------------------------------------
#■DBレコードを検索してprof_idをリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref
#		{
#			member_id     => 会員識別ID (必須),
#			prof_status   => 講師ステータス
#		}
#
#[戻り値]
#	prof_idを格納したarrayref
#---------------------------------------------------------------------
sub get_prof_id_list {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}
	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'member_id',
		'prof_status'
	);
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "member_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "prof_status") {
			if($v =~ /^(0|1)$/) {
				$params->{$k} = $v + 0;
			} else {
				delete $params->{$k};
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{member_id}) {
		push(@wheres, "favs.member_id=$params->{member_id}");
	} else {
		croak "The parameter `member_id` is required.";
	}
	if(defined $params->{prof_status}) {
		push(@wheres, "profs.prof_status=$params->{prof_status}");
	}

	#SELECT
	my @list;
	{
		my $sql = "SELECT favs.prof_id FROM favs LEFT JOIN profs ON favs.prof_id=profs.prof_id";
		my $where = join(" AND ", @wheres);
		$sql .= " WHERE ${where}";
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			push(@list, $ref->{prof_id});
		}
		$sth->finish();
	}
	#
	return \@list;
}


1;
