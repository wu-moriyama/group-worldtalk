package FCC::Action::Prof::BilpdmfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use CGI::Utils;
use FCC::Class::Pdm;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "bilpdm");
	unless($proc) {
		$proc = $self->create_proc_session_data("bilpdm");
		#請求可能なレッスン情報を検索
		my $opdm = new FCC::Class::Pdm(conf=>$self->{conf}, db=>$self->{db});
		my $res = $opdm->get_demand_target($prof_id);
		#
		$proc->{in} = $res;
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
