package FCC::Action::Reg::_SuperAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::_SuperAction);

sub get_proc_session_data {
	my($self, $pkey, $pname) = @_;
	if( ! defined $pkey ) { $pkey = ""; }
	#プロセスキー
	if($pkey eq "" || $pkey !~ /^[a-zA-Z0-9]{32}$/) {
		return undef;
	}
	#プロセスデータ
	my $proc = $self->{session}->{data}->{proc};
	if( ! $proc || ! $proc->{pkey} || $proc->{pkey} ne $pkey || $proc->{pname} ne $pname ) {
		return undef;
	}
	#
	return $proc;
}

sub set_proc_session_data {
	my($self, $proc) = @_;
	$self->{session}->{data}->{proc} = $proc;
	$self->{session}->update( { proc => $proc } );
}

sub create_proc_session_data {
	my($self, $pname) = @_;
	my $pkey = $self->{session}->generate_digest();
	my $proc = {
		pkey => $pkey,
		pname => $pname,
		in => {},
		errs => []
	};
	$self->{session}->{data}->{proc} = $proc;
	$self->{session}->update( { proc => $proc } );
	return $proc;
}

sub del_proc_session_data {
	my($self) = @_;
	my $proc = $self->{session}->{data}->{proc};
	delete $self->{session}->{data}->{proc};
	$self->{session}->update( { proc => undef } );
	return $proc;
}

1;
