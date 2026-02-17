package FCC::Action::Mypage::BnkcptshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "bnk");
	my $bnk = {};
	while( my($k, $v) = each %{$proc->{in}} ) {
		$bnk->{$k} = $v;
	}
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#
	$context->{bnk} = $bnk;
	return $context;
}

1;
