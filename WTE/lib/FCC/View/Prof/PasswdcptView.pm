package FCC::View::Prof::PasswdcptView;
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
	my $t = $self->load_template();
	my $cookie_string_list = $self->{session}->logoff_cookie_strings();
	my $hdrs = {
		"Set-Cookie" => $cookie_string_list
	};
	$self->print_html($t, $hdrs);
}

1;
