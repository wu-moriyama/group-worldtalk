package FCC::View::Pwdrst::CptshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Pwdrst::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	$self->print_html($t);
}

1;
