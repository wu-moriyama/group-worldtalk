package FCC::Class::Mypg;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::String::Checker;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{memd} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{db} = $args{db};
	#
	$self->{memcache_key_prefix} = "mypg_";
}

#---------------------------------------------------------------------
#■セット
#---------------------------------------------------------------------
#[引数]
#	1.hashref
#	{
#		mypg_id => ページ識別ID,
#		mypg_title => ページタイトル,
#		mypg_content => ページ内容
#	}
#[戻り値]
#	成功すれば1を返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub set {
	my($self, $ref) = @_;
	if( ! defined $ref || ref($ref) ne "HASH" ) {
		croak "the 1st augument must be a hashref.";
	}
	if( ! $ref->{mypg_id} ) {
		croak "mypg_id is required.";
	} elsif($ref->{mypg_id} !~ /^\d+$/) {
		croak "mypg_id is invalid.";
	} elsif($ref->{mypg_id} < 1 || $ref->{mypg_id} > 128) {
		croak "mypg_id is invalid.";
	}
	#DBにセット
	$self->_set_to_db($ref);
	#memcacheにセット
	$self->_set_to_memcache($ref);
	#
	return 1;
}

sub _set_to_db {
	my($self, $ref) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my $sql;
	if( ! $ref->{mypg_title} && ! $ref->{mypg_content} ) {
		my $id = $ref->{mypg_id};
		$sql = "DELETE FROM mypgs WHERE mypg_id=${id}";
	} else {
		my @klist;
		my @vlist;
		while( my($k, $v) = each %{$ref} ) {
			push(@klist, $k);
			my $qv = $dbh->quote($v);
			push(@vlist, $qv);
		}
		$sql = "REPLACE INTO mypgs (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";
	}
	eval {
		$self->{db}->{dbh}->do($sql);
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to set a record to mypgs table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
		croak $msg;
	}
}

sub _set_to_memcache {
 	my($self) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#全テンプレート情報を取得
	my $sth = $dbh->prepare("SELECT * FROM mypgs");
	$sth->execute();
	my %data;
	while( my $ref = $sth->fetchrow_hashref ) {
		my $mypg_id = $ref->{mypg_id};
		my $key = $self->{memcache_key_prefix} . $mypg_id;
		my $mem = $self->{memd}->set($key, $ref);
		unless($mem) {
			$sth->finish();
			my $msg = "failed to set a template data to memcache. : mypg_id=${mypg_id}";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
			croak $msg;
			last;
		}
	}
	$sth->finish();
}

#---------------------------------------------------------------------
#■テンプレート内容を取得
#---------------------------------------------------------------------
#[引数]
#	1.ページ識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get {
	my($self, $mypg_id) = @_;
	if($mypg_id eq '' || $mypg_id =~ /[^\d]/) {
		croak "Invalid Parameters";
	}
	# memcacheから取得
	{
		my $ref = $self->get_from_memcache($mypg_id);
		if( $ref && $ref->{mypg_id} ) {
			return $ref;
		}
	}
	# DBから取得
	{
		my $ref = $self->get_from_db($mypg_id);
		if( $ref ) {
			#memcacheにセット
			$self->_set_to_memcache();
			#
			return $ref;
		}
	}
	return "";
}

#---------------------------------------------------------------------
#■memcacheからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.ページ識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_from_memcache {
	my($self, $mypg_id) = @_;
	if($mypg_id eq '' || $mypg_id =~ /[^\d]/) {
		croak "Invalid Parameters";
	}
	my $key = $self->{memcache_key_prefix} . $mypg_id;
	my $ref = $self->{memd}->get($key);
	return $ref;
}

#---------------------------------------------------------------------
#■DBからレコードを取得
#---------------------------------------------------------------------
#[引数]
#	1.ページ識別ID（必須）
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_from_db {
	my($self, $mypg_id) = @_;
	if($mypg_id eq '' || $mypg_id =~ /[^\d]/) {
		croak "Invalid Parameters";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $ref = $dbh->selectrow_hashref("SELECT * FROM mypgs WHERE mypg_id=${mypg_id}");
	#
	return $ref;
}

#---------------------------------------------------------------------
#■タイトル一覧を取得
#---------------------------------------------------------------------
#[引数]
#	1.なし
#[戻り値]
#	キーに識別ID, 値にタイトルを格納したhashref
#---------------------------------------------------------------------
sub get_titles {
	my($self) = @_;
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sth = $dbh->prepare("SELECT mypg_id, mypg_title FROM mypgs");
	$sth->execute();
	my %h;
	while( my($id, $title) = $sth->fetchrow_array ) {
		$h{$id} = $title;
	}
	$sth->finish();
	#
	return \%h;
}

#---------------------------------------------------------------------
#■編集の入力チェック
#---------------------------------------------------------------------
#[引数]
#	1.入力データのキーのarrayref（必須）
#	2.入力データのhashref（必須）
#[戻り値]
#	エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub input_check {
	my($self, $names, $in) = @_;
	my %cap = (
		mypg_title => 'ページタイトル',
		mypg_content => 'HTML'
	);
	#入力値のチェック
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		#ページタイトル
		if($k eq "mypg_title") {
			my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100) {
				push(@errs, [$k, "\"$cap{$k}\" は100文字以内で入力してください。"]);
			}
		#HTML
		} elsif($k eq "mypg_content") {
			my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 100000) {
				push(@errs, [$k, "\"$cap{$k}\" は100000文字以内で入力してください。"]);
			}
		}
	}
	#
	return @errs;
}

1;
