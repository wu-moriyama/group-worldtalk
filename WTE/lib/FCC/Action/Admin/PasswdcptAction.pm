package FCC::Action::Admin::PasswdcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	$self->del_proc_session_data();
	$self->{session}->logoff();
	return $context;
}

1;
