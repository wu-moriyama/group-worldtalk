package FCC::Action::Admin::TplmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Tmpl;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "tplmod");
	#インスタンス
	my $otmpl = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#
	unless($proc) {
		my $tmpls = $otmpl->get_tmpls();
		my $tmpl_id = $self->{q}->param("tmpl_id");
		if( ! defined $tmpl_id || $tmpl_id eq "" || ! $tmpls->{$tmpl_id} ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("tplmod");
		$proc->{in}->{tmpl_id} = $tmpl_id;
		$proc->{in}->{tmpl_title} = $tmpls->{$tmpl_id};
		$proc->{in}->{tmpl_content} = $otmpl->get_from_db($tmpl_id);
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

1;
