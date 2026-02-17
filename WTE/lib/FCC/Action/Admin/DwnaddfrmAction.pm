package FCC::Action::Admin::DwnaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;
use FCC::Class::Dct;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwnadd");
	unless($proc) {
		$proc = $self->create_proc_session_data("dwnadd");
		#初期値
		$proc->{in} = {
			dwn_weight => 0,
			dwn_period => 72
		};
		#
		$self->set_proc_session_data($proc);
	}
	#カテゴリーリスト
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $dct_list = $odct->get_available_list();
	#
	$context->{proc} = $proc;
	$context->{dct_list} = $dct_list;
	return $context;
}


1;
