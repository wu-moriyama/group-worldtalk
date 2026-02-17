package FCC::Action::Admin::LogoffAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
	my($self) = @_;
	$self->{session}->logoff();
	my $context = {};
	return $context;
}

1;
