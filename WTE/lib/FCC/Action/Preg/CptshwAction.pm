package FCC::Action::Preg::CptshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Preg::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッションを削除
	$self->del_proc_session_data();
	$self->{session}->logoff();
	#
	return $context;
}

1;
