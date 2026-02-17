package FCC::View::Preg::DefaultView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Preg::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	my $t = $self->load_template();
	$self->print_html($t);
}

1;
