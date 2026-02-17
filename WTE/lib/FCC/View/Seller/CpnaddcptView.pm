package FCC::View::Seller::CpnaddcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Seller::_SuperView);
use CGI::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
	}
	my $t = $self->load_template();
	while( my($k, $v) = each %{$context->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if( $k =~ /^coupon_(max|price)$/ ) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	$self->print_html($t);
}

1;
