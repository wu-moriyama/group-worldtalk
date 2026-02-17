package FCC::Action::Reg::CfmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Reg::_SuperAction);
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "reg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	$context->{proc} = $proc;
	return $context;
}

1;
