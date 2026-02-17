package FCC::View::Admin::SyscnfcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
	}
	my $t = $self->load_template();
	$self->print_html($t);
}

1;
