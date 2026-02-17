package FCC::Action::Prof::NtemodfrmAction;
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
	my $proc = $self->get_proc_session_data($pkey, "ntemod");
	#インスタンス
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#
	unless($proc) {
		my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
		if( ! defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("ntemod");
		#講師情報を取得
		my $prof = $oprof->get_from_db($prof_id);
		unless($prof) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = {
			prof_id => $prof_id,
			prof_note => $prof->{prof_note}
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
