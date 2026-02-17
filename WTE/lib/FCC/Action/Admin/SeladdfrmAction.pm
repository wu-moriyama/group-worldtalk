package FCC::Action::Admin::SeladdfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "seladd");
	unless($proc) {
		$proc = $self->create_proc_session_data("seladd");
		#初期値
		$proc->{in} = {
			seller_status => 1,
			seller_margin_ratio => $self->{conf}->{seller_margin_ratio}
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
