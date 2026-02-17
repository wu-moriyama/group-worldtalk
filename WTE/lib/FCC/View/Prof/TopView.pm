package FCC::View::Prof::TopView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $prof = $context->{prof};
	my $prof_note = CGI::Utils->new()->escapeHtml($prof->{prof_note});
	$prof_note =~ s/\n/<br\/>/g;
	my $t = $self->load_template();
	$t->param("prof_note" => $prof_note);
	#
	$self->print_html($t);
}

1;
