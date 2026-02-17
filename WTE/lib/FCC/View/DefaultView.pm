package FCC::View::DefaultView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	my $m = $self->{q}->param('m');
	if($m) {
		if($m =~ /[^0-9a-zA-Z]/) {
			$self->error404;
		}
	} else {
		$m = 'index';
	}
	$m = ucfirst $m;
	my $tmpl = "./template/${m}.html";
	if(-e $tmpl) {
		my $t = $self->load_template($tmpl);
		$self->print_html($t);
	} else {
		$self->error404;
	}
}

1;
