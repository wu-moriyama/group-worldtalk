package FCC::View::Mypage::MbrmodcptView;
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
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}

	#表示言語のCookie
	my @set_cookies;
	{
		my $cookie = new CGI::Cookie(
			-name    => 'member_lang',
			-value   => $self->{session}->{data}->{member}->{member_lang},
			-path    => $self->{conf}->{CGI_DIR_URL_PATH},
			-expires => '+1y',
			-secure  => 1
		);
		my $cookie_string = $cookie->as_string();
		push(@set_cookies, $cookie_string);
	}
	my $hdrs = { "Set-Cookie" => \@set_cookies };
	$self->print_html($t, $hdrs);
}

1;
