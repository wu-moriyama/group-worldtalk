package FCC::Class::Prep;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
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
	#prepsテーブルの全カラム名のリスト
	$self->{table_cols} = {
		prep_id      => "識別ID",
		prof_id      => "投稿者の講師識別ID",
		member_id    => "レポート対象の会員識別ID",
		lsn_id       => "レッスン識別ID",
		prep_cdate   => "投稿日時",
		prep_status  => "ステータス",
		prep_content => "本文"
	};
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
		#メッセージ
		if($k eq "prep_content") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 1000) {
				push(@errs, [$k, "\"$cap{$k}\" は1000文字以内で入力してください。"]);
			}
		} elsif($k eq "prep_status") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v !~ /^(0|1)$/) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		}
	}
	#
	return @errs;
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
	my($self, $prep_id) = @_;
	if( ! $prep_id || $prep_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT preps.*, members.*, profs.* FROM preps";
	$sql .= " LEFT JOIN members ON preps.member_id=members.member_id";
	$sql .= " LEFT JOIN profs ON preps.prof_id=profs.prof_id";
	$sql .= " WHERE preps.prep_id=${prep_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_prof_info($ref);
		$self->add_member_info($ref);
		$self->add_datetime_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■レコード登録
#---------------------------------------------------------------------
#[引数]
#	1: hashref
#[戻り値]
#	登録したhashref
#---------------------------------------------------------------------
sub add {
	my($self, $ref) = @_;
	#識別IDのチェック
	my $prof_id = $ref->{prof_id};
	if( ! defined $prof_id || $prof_id =~ /[^\d]/) {
		croak "the value of prof_id in parameters is invalid.";
	}
	my $member_id = $ref->{member_id};
	if( ! defined $member_id || $member_id =~ /[^\d]/) {
		croak "the value of member_id in parameters is invalid.";
	}
	my $lsn_id = $ref->{lsn_id};
	if( ! defined $lsn_id || $lsn_id =~ /[^\d]/) {
		croak "the value of lsn_id in parameters is invalid.";
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
	$rec->{prep_cdate} = $now;
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
	my $prep_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO preps (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$prep_id = $dbh->{mysql_insertid};
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to insert a record to preps table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#レコード情報を取得
	my $prep = $self->get($prep_id);
	#
	return $prep;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないprep_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $prep_id) = @_;
	#識別IDのチェック
	if( ! defined $prep_id || $prep_id =~ /[^\d]/) {
		croak "the value of prep_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#データ情報を取得
	my $prep = $self->get($prep_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM preps WHERE prep_id=${prep_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in preps table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $prep;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			prep_id       => 識別ID,
#			prof_id       => 講師識別ID,
#			member_id     => 会員識別ID,
#			lsn_id        => レッスン識別ID,
#			prep_status   => ステータス（0 or 1）,
#			offset        => オフセット値（デフォルト値：0）,
#			limit         => リミット値（デフォルト値：20）,
#			sort          => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit  => 20,
#			sort   =>[ ['prep_id', "DESC"] ]
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
		'prep_id',
		'prof_id',
		'member_id',
		'lsn_id',
		'prep_status',
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
		sort =>[ ['prep_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(prep|prof|member|lsn)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "prep_status") {
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
				if($key !~ /^(prep_id|member_id|prof_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{prep_id}) {
		push(@wheres, "preps.prep_id=$params->{prep_id}");
	}
	if(defined $params->{prof_id}) {
		push(@wheres, "preps.prof_id=$params->{prof_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "preps.member_id=$params->{member_id}");
	}
	if(defined $params->{lsn_id}) {
		push(@wheres, "preps.lsn_id=$params->{lsn_id}");
	}
	if(defined $params->{prep_status}) {
		push(@wheres, "preps.prep_status=$params->{prep_status}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(prep_id) FROM preps";
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
		my $sql = "SELECT preps.*, members.*, profs.* FROM preps";
		$sql .= " LEFT JOIN members ON preps.member_id=members.member_id";
		$sql .= " LEFT JOIN profs ON preps.prof_id=profs.prof_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "preps.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			$self->add_prof_info($ref);
			$self->add_member_info($ref);
			$self->add_datetime_info($ref);
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

sub add_member_info {
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

sub add_datetime_info {
	my($self, $ref) = @_;
	my %prep_cdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{prep_cdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %prep_cdate_fmt ) {
		$ref->{"prep_cdate_${k}"} = $v;
	}
}

1;
