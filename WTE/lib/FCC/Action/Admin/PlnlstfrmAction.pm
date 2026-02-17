package FCC::Action::Admin::PlnlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Plan;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "plnmod");
	unless($proc) {
		$proc = $self->create_proc_session_data("plnmod");
		#全プラン情報を取得
		my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
		my $plan_list = $opln->get_all();
		#
		my $max = $self->{conf}->{plan_max};
		my $list = [];
		for( my $i=1; $i<=$max; $i++ ) {
			my $h = {};
			my $pln_sort = $i * 10;
			if( $plan_list->[$i-1] ) {
				$h = $plan_list->[$i-1];
			}
			$h->{i} = $i;
			$h->{pln_sort} = $pln_sort;
			push(@{$list}, $h);
		}
		#
		$proc->{in} = $list;
		$self->set_proc_session_data($proc);
	}
	#
	$context->{proc} = $proc;
	return $context;
}


1;
