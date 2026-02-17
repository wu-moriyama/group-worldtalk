package FCC::Action::Mypage::MbrdelcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#ログアウト処理
	$self->{session}->logoff();
	#
	return $context;
}

1;
