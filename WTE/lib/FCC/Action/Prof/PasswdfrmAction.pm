package FCC::Action::Prof::PasswdfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Prof;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "passwd");
	#
	unless($proc) {
		$proc = $self->create_proc_session_data("passwd");
		#営業会社情報を取得
		my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
		my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		my $prof = $oprof->get_from_db($prof_id);
		unless($prof) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = $prof;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

1;
