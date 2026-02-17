package FCC::View::Mypage::LogoffView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Cookie;

sub dispatch {
	my($self, $context) = @_;
	#
	if($context->{redirect}) {
		my $rurl = $self->{conf}->{www_host_url} . $context->{redirect};
		print "Location: http://${rurl}\n\n";
	} else {
		my $lang = $context->{member}->{member_lang};
		my $t = $self->load_template(undef, undef, $lang);
		$t->param('member_lang' => $lang);
		#
		my $cookie_string_list = $self->{session}->logoff_cookie_strings();

		#表示言語のCookie
		{
			my $cookie = new CGI::Cookie(
				-name    => 'member_lang',
				-value   => $lang,
				-path    => $self->{conf}->{CGI_DIR_URL_PATH},
				-expires => '+1y',
				-secure  => 1
			);
			my $cookie_string = $cookie->as_string();
			push(@{$cookie_string_list}, $cookie_string);
		}
		
		my $hdrs = {
			"Set-Cookie" => $cookie_string_list
		};
		$self->print_html($t, $hdrs);
	}
}

1;
