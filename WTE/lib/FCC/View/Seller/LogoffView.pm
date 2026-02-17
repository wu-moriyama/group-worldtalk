package FCC::View::Seller::LogoffView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Seller::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	my $t = $self->load_template();
	my $cookie_string_list = $self->{session}->logoff_cookie_strings();
	my $hdrs = {
		"Set-Cookie" => $cookie_string_list
	};
	$self->print_html($t, $hdrs);
}

1;
