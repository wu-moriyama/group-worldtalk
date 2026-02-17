package FCC::Class::Buzz;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::Date::Utils;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#buzzesテーブルの全カラム名のリスト
	$self->{table_cols} = {
		buz_id        => "識別ID",
		member_id     => "投稿者の会員識別ID",
		prof_id       => "クチコミ対象の講師識別ID",
		buz_cdate     => "投稿日時",
		buz_show      => "表示フラグ",
		buz_content   => "本文"
	};
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
		if($k eq "buz_content") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 300) {
				push(@errs, [$k, "\"$cap{$k}\" は300文字以内で入力してください。"]);
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
	my($self, $buz_id) = @_;
	if( ! $buz_id || $buz_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sql = "SELECT buzzes.*, members.*, profs.* FROM buzzes";
	$sql .= " LEFT JOIN members ON buzzes.member_id=members.member_id";
	$sql .= " LEFT JOIN profs ON buzzes.prof_id=profs.prof_id";
	$sql .= " WHERE buzzes.buz_id=${buz_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->member_info($ref);
		$self->prof_info($ref);
		$self->add_datetime_info($ref);
	}
	return $ref;
}

#---------------------------------------------------------------------
#■クチコミ登録
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
	$rec->{buz_cdate} = $now;
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
	my $buz_id;
	my $last_sql;
	eval {
		$last_sql = "INSERT INTO buzzes (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
		$dbh->do($last_sql);
		$buz_id = $dbh->{mysql_insertid};
		#
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert a record to buzzes table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#クチコミ情報を取得
	my $buz = $self->get($buz_id);
	#
	return $buz;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないbuz_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $buz_id) = @_;
	#識別IDのチェック
	if( ! defined $buz_id || $buz_id =~ /[^\d]/) {
		croak "the value of buz_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#情報を取得
	my $buz = $self->get($buz_id);
	#Delete
	my $deleted;
	my $last_sql;
	eval {
		$last_sql = "DELETE FROM buzzes WHERE buz_id=${buz_id}";
		$deleted = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a record in buzzes table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $buz;
}

#---------------------------------------------------------------------
#■レビュー（口コミ）表示フラグをセット
#---------------------------------------------------------------------
#[引数]
#	1:レッスン識別ID
#[戻り値]
#	アップデートされたレコードの数（通常は1が返る）
#---------------------------------------------------------------------
sub set_buz_show {
	my($self, $buz_id, $buz_show) = @_;
	if( ! $buz_id || $buz_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	if( $buz_show !~ /^(0|1)$/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#アップデート
	my $last_sql;
	my $updated = 0;
	eval {
		$last_sql = "UPDATE buzzes SET buz_show=${buz_show} WHERE buz_id=${buz_id}";
		$updated = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to update a buzz record in buzzes table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#
	return $updated;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			buz_id => 識別ID,
#			prof_id => 講師識別ID,
#			member_id => 会員識別ID,
#			buz_show => 表示ステータス,
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
		'buz_id',
		'prof_id',
		'member_id',
		'buz_show',
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
		sort =>[ ['buz_id', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(buz|prof|member)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "buz_show") {
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
				if($key !~ /^(buz_id)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{buz_id}) {
		push(@wheres, "buzzes.buz_id=$params->{buz_id}");
	}
	if(defined $params->{prof_id}) {
		push(@wheres, "buzzes.prof_id=$params->{prof_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "buzzes.member_id=$params->{member_id}");
	}
	if(defined $params->{buz_show}) {
		push(@wheres, "buzzes.buz_show=$params->{buz_show}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(buz_id) FROM buzzes";
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
		my $sql = "SELECT buzzes.*, profs.* FROM buzzes";
		$sql .= " LEFT JOIN profs ON buzzes.prof_id=profs.prof_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "buzzes.$ary->[0] $ary->[1]");
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
			$self->prof_info($ref);
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
	my %buz_cdate_fmt = FCC::Class::Date::Utils->new(time=>$ref->{buz_cdate}, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %buz_cdate_fmt ) {
		$ref->{"buz_cdate_${k}"} = $v;
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

sub prof_info {
	my($self, $ref) = @_;
	unless($ref) { return; }
	my $prof_id = $ref->{prof_id};
	unless($prof_id) { return; }
	$ref->{prof_country_name} = $self->{prof_country_hash}->{$ref->{prof_country}};
	$ref->{prof_residence_name} = $self->{prof_country_hash}->{$ref->{prof_residence}};
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
		$ref->{"prof_logo_${s}_w"} = $self->{conf}->{"prof_logo_${s}_w"};
		$ref->{"prof_logo_${s}_h"} = $self->{conf}->{"prof_logo_${s}_h"};
	}
}

1;
