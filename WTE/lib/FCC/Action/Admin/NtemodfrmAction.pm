package FCC::Action::Admin::NtemodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "ntemod");
	#
	unless($proc) {
		$proc = $self->create_proc_session_data("ntemod");
		#メモを取得
		$proc->{in} = {
			note => $self->get_note()
		};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

sub get_note {
	my($self) = @_;
	my $base_dir = $self->{conf}->{BASE_DIR};
	my $fcc_selector = $self->{conf}->{FCC_SELECTOR};
	my $notef = "${base_dir}/data/${fcc_selector}.note.cgi";
	unless( -e $notef ) { return ""; }
	my $note = "";
	open my $fh, "<", $notef;
	my @lines = <$fh>;
	close($fh);
	return join("", @lines);
}

1;
