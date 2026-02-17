package FCC::Action::Mypage::PasswdcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#ログアウト処理
	$self->{session}->logoff();
	#
	return $context;
}

1;
