package FCC::Action::Preg::FrmshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Preg::_SuperAction);
use FCC::Class::Prof;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "preg");
	#インスタンス
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db});
	unless($proc) {
		$proc = $self->create_proc_session_data("preg");
		$self->set_proc_session_data($proc);
	}
	#国選択肢リスト
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	my $country_list = $oprof->get_prof_country_list();
	#
	$context->{proc} = $proc;
	$context->{country_list} = $country_list;
	return $context;
}

1;
