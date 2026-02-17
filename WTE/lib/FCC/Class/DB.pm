package FCC::Class::DB;
$VERSION = 1.00;
use strict;
use warnings;
use Carp;
use base qw(FCC::_Super);
use DBI;
use FCC::Class::Log;

sub init {
	my($self, %args) = @_;
	if($args{dbh}) {
		$self->{dbh} = $args{dbh};
	}
	$self->{conf} = $args{conf};
}

sub connect_db {
	my($self) = @_;
	if($self->{dbh}) {
		return $self->{dbh};
	} else {
		my $db_host = $self->{conf}->{db_host};
		my $db_name = $self->{conf}->{db_name};
		my $db_user = $self->{conf}->{db_user};
		my $db_pass = $self->{conf}->{db_pass};
		my $db_port = $self->{conf}->{db_port};
		my $dsn = "dbi:mysql:database=${db_name};host=${db_host}";
		if($db_port) {
			$dsn .= ";port=${db_port}";
		}
		my $dbh;
		eval {
			$dbh = DBI->connect(
				"${dsn}",
				"${db_user}", "${db_pass}",
				{RaiseError => 1, AutoCommit => 0}
			);
		};
		if($@) {
			$self->connect_db_error($self->{conf}, "failed to connect to the db. : $@");
			return undef;
		}
		$self->{dbh} = $dbh;
		return $dbh;
	}
}

sub connect_db_error {
	my($self, $c, $msg) = @_;
	#ロギング
	FCC::Class::Log->new(conf=>$c)->loging("error", $msg);
	# croak
	croak $msg;
}

sub disconnect_db {
	my($self) = @_;
	#DB接続
	if($self->{dbh}) {
		$self->{dbh}->disconnect;
	}
}

sub get_dbh {
	my($self) = @_;
	return $self->{dbh};
}

1;
