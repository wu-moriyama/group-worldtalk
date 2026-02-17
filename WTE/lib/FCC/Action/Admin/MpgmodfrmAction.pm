package FCC::Action::Admin::MpgmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Mypg;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mpgmod");
	#インスタンス
	my $omypg = new FCC::Class::Mypg(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#
	unless($proc) {
		my $mypg_id = $self->{q}->param("mypg_id");
		if( ! defined $mypg_id || $mypg_id eq "" || $mypg_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("mpgmod");
		#情報を取得
		my $mypg = $omypg->get($mypg_id);
		unless($mypg) {
			$mypg = {};
			$mypg->{mypg_id} = $mypg_id;
			$mypg->{mypg_title} = "";
			$mypg->{mypg_content} = "";
		}
		$proc->{in} = $mypg;
		#
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
