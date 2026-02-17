package FCC::Action::Mypage::Crdfrmshw2Action;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Plan;
use FCC::Class::Auto;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "crd");
	#
	unless($proc) {
		$proc = $self->create_proc_session_data("crd");
		$proc->{in} = {};
		$self->set_proc_session_data($proc);
	}
	#プラン
	my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
	my $plan_list = $opln->get_all({pln_status => 1});
	#月額課金会員かどうか
	my $oauto = new FCC::Class::Auto(conf=>$self->{conf}, db=>$self->{db});
	my $auto = $oauto->is_subscription_member($member_id);
	if($auto) {
		$auto->{is_subscription_member} = 1;
	} else {
		$auto = { is_subscription_member => 0 };
	}
	#
	$context->{proc} = $proc;
	$context->{plan_list} = $plan_list;
	$context->{auto} = $auto;
	return $context;
}

1;
