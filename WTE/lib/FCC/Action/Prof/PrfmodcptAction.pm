package FCC::Action::Prof::PrfmodcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	$self->del_proc_session_data();
	return $context;
}

1;
