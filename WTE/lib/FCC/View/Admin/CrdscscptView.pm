package FCC::View::Admin::CrdscscptView;
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
	$t->param("crd_id" => $context->{in}->{crd_id});
	$self->print_html($t);
}

1;
