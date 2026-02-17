package FCC::Class::Syscnf;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{memd} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{memd} = $args{memd};
	$self->{db} = $args{db};
	$self->{force_db} = $args{force_db};
	#
	$self->{memcache_key} = "sysconf";
	$self->{self_check_key} = "sysconf";
}

#---------------------------------------------------------------------
#■一括セット
#---------------------------------------------------------------------
#[引数]
#	1.設定情報を格納したhashref（必須）
#[戻り値]
#	成功すれば引数に与えたhashrefを返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub set {
	my($self, $ref) = @_;
	$ref->{self_check_key} = $self->{self_check_key};
	#DBにセット
	$self->set_to_db($ref);
	#memcacheにセット
	$self->set_to_memcache($ref);
	#
	return $ref;
}

sub set_to_db {
	my($self, $ref) = @_;
	#DB接続
	$self->{db}->connect_db();
	#
	my $sql = "REPLACE INTO sysconf (name, value) VALUES ";
	my @value_list;
	while( my($k, $v) = each %{$ref} ) {
		my $q_k = $self->{db}->{dbh}->quote($k);
		my $q_v = $self->{db}->{dbh}->quote($v);
		if( ! defined $v || $v eq "" ) { $q_v = "NULL"; }
		push(@value_list, "(${q_k}, ${q_v})");
	}
	$sql .= join(",", @value_list);
	eval {
		$self->{db}->{dbh}->do($sql);
		$self->{db}->{dbh}->commit();
	};
	if($@) {
		$self->{db}->{dbh}->rollback();
		my $msg = "failed to set system configuration data to database.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : ${sql}");
		croak $msg;
	}
}

sub set_to_memcache {
	my($self, $ref) = @_;
	my $mem = $self->{memd}->set($self->{memcache_key}, $ref);
	unless($mem) {
		my $msg = "failed to set system configuration data to memcache.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", $msg);
		croak $msg;
	}
}

#---------------------------------------------------------------------
#■全設定情報を一括取得
#---------------------------------------------------------------------
#[引数]
#	なし
#[戻り値]
#	全設定情報を格納したhashrefを返す。
#	失敗すればcroakする。
#
# もしmemcacheにデータがなければDBから取得する
# ただし、$self->{force_db} = 1 がセットされていれば、直接DBから取り出
# しにいく
#---------------------------------------------------------------------
sub get {
	my($self) = @_;
	#DB強制取得
	if($self->{force_db}) {
		my $cnf = $self->get_from_db();
		return $cnf;
	}
	#memcacheから取得
	{
		my $cnf = $self->get_from_memcache();
		if( $cnf && ref($cnf) eq "HASH" ) {
			my $key_num = scalar keys %{$cnf};
			if($key_num > 0 && $cnf->{self_check_key} eq $self->{self_check_key}) {
				return $cnf;
			}
		}
	}
	#DBから取得
	{
		my $cnf = $self->get_from_db();
		#memcacheにセット
		$self->set_to_memcache($cnf);
		#
		return $cnf;
	}
}

sub get_from_memcache {
	my($self) = @_;
	if( ! defined $self->{memd} || ! $self->{memd} ) {
		croak "no memd object.";
	}
	my $cnf = $self->{memd}->get($self->{memcache_key});
	return $cnf;
}

sub get_from_db {
	my($self) = @_;
	unless( defined $self->{db} ) { croak "no db object."; }
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $sth = $dbh->prepare("SELECT name, value FROM sysconf");
	$sth->execute();
	my $cnf = {};
	while( my($name, $value) = $sth->fetchrow_array ) {
		$cnf->{$name} = $value;
	}
	$sth->finish();
	#
	return $cnf;
}

1;
