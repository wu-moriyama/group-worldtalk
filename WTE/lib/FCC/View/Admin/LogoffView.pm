package FCC::View::Admin::LogoffView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	my $t = $self->load_template();
	#
	my $cs_string = "$self->{conf}->{FCC_SELECTOR}_sid=dummy; path=$self->{conf}->{CGI_DIR_URL_PATH}; expires=Thu, 01-Jan-1970 00:00:00 GMT;";
	my $ca_string = "$self->{conf}->{FCC_SELECTOR}_auto_logon_enable=0; path=$self->{conf}->{CGI_DIR_URL_PATH};  expires=Thu, 01-Jan-1970 00:00:00 GMT;";
	#
	$t->param("cookie_string_sid" => $cs_string);
	$t->param("cookie_string_auto_logon_enable" => $ca_string);
	#
	my $hdrs = {
		"Set-Cookie" => [$cs_string, $ca_string]
	};
	$self->print_html($t, $hdrs);
}

1;
