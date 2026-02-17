package FCC::Action::Mypage::CrdcclshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#
	return $context;
}

1;
