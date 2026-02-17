package FCC::View::Mypage::MbrdelcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	while( my($k, $v) = each %{$context->{in}} ) {
		my $qv = CGI::Utils->new()->escapeHtml($v);
		$t->param($k => $qv);
		$t->param("session_${k}" => $qv);
	}
	my $cookie_string_list = $self->{session}->logoff_cookie_strings();
	my $hdrs = {
		"Set-Cookie" => $cookie_string_list
	};
	$self->print_html($t, $hdrs);
}

1;
