package FCC::Action::Admin::ParentAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Passwd;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#メモ
	$context->{note} = $self->get_note();
	#ログオンアカウント情報を取得
	my $pw = new FCC::Class::Passwd(conf=>$self->{conf});
	unless($pw) {
		$context->{fatalerrs} = [$!];
		return $context;
	}
	$context->{acnt} = $pw->get($self->{session}->{data}->{id});
#
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
