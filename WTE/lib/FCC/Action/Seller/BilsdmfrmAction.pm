package FCC::Action::Seller::BilsdmfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use CGI::Utils;
use FCC::Class::Sdm;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "bilsdm");
	unless($proc) {
		$proc = $self->create_proc_session_data("bilsdm");
		#請求可能なレッスン情報を検索
		my $osdm = new FCC::Class::Sdm(conf=>$self->{conf}, db=>$self->{db});
		my $res = $osdm->get_demand_target($seller_id);
		#
		$proc->{in} = $res;
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
