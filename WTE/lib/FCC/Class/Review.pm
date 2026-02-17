package FCC::Class::Review;
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
}

#---------------------------------------------------------------------
#■レビュー（口コミ）表示フラグをセット
#---------------------------------------------------------------------
#[引数]
#	1:レッスン識別ID
#[戻り値]
#	アップデートされたレコードの数（通常は1が返る）
#---------------------------------------------------------------------
sub set_lsn_review_show {
	my($self, $lsn_id, $lsn_review_show) = @_;
	if( ! $lsn_id || $lsn_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	if( $lsn_review_show !~ /^(0|1)$/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#アップデート
	my $last_sql;
	my $updated = 0;
	eval {
		$last_sql = "UPDATE lessons SET lsn_review_show=${lsn_review_show} WHERE lsn_id=${lsn_id}";
		$updated = $dbh->do($last_sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to update a lesson record in lessons table.";
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
#			lsn_id => スケジュール識別ID,
#			prof_id => 講師識別ID,
#			member_id => 会員識別ID,
#			lsn_review_show => 表示ステータス,
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['lsn_member_repo_date', "DESC"] ]
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
		'lsn_id',
		'prof_id',
		'member_id',
		'lsn_review_show',
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
		sort =>[ ['lsn_member_repo_date', "DESC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k =~ /^(lsn|prof|member)_id$/) {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			} else {
				$params->{$k} = $v + 0;
			}
		} elsif($k eq "lsn_review_show") {
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
				if($key !~ /^(lsn_id|lsn_stime|lsn_member_repo_date)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{lsn_id}) {
		push(@wheres, "lessons.lsn_id=$params->{lsn_id}");
	}
	if(defined $params->{prof_id}) {
		push(@wheres, "lessons.prof_id=$params->{prof_id}");
	}
	if(defined $params->{member_id}) {
		push(@wheres, "lessons.member_id=$params->{member_id}");
	}
	if(defined $params->{lsn_review_show}) {
		push(@wheres, "lessons.lsn_review_show=$params->{lsn_review_show}");
	}
	push(@wheres, "lessons.lsn_review IS NOT NULL && lessons.lsn_review<>''");
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
		my $sql = "SELECT lessons.* FROM lessons";
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
