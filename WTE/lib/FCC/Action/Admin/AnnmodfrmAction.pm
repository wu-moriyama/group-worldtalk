package FCC::Action::Admin::AnnmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Ann;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "annmod");
	#
	unless($proc) {
		my $ann_id = $self->{q}->param("ann_id");
		if( ! defined $ann_id || $ann_id eq "" || $ann_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("annmod");
		#お知らせ情報を取得
		my $oann = new FCC::Class::Ann(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		my $ann = $oann->get_from_db($ann_id);
		unless($ann) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#
		$proc->{in} = $ann;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
