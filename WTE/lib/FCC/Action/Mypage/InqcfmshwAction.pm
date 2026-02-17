package FCC::Action::Mypage::InqcfmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "inq");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	if( ! $proc->{in}->{confirm_ok} ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
