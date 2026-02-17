package FCC::Action::Admin::FmladdfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "fmladd");
	unless($proc) {
		$proc = $self->create_proc_session_data("fmladd");
		#初期値
		$proc->{in} = {
			fml_content => $self->{conf}->{fml_content_default}
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

1;
