package FCC::View::Admin::AuthinitformView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#エラーの評価
	if($context->{errs}) {
		$self->error($context->{errs});
	} else {
		my $t = $self->load_template();
		$self->print_html($t);
	}
}

1;
