package FCC::View::Prof::IndexView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#エラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#
	my $t = $self->load_template();
	$t->param('epoch' => time);
	#sid用Cookie
	my $login_cookie_string = $self->{session}->login_cookie_string();
	my @set_cookies = ($login_cookie_string);
	if($self->{session}->{data}->{auto_login_enable} eq "1") {
		#auto_logon_enable用Cookie
		my $auto_login_cookie_string = $self->{session}->auto_login_cookie_string();
		push(@set_cookies, $auto_login_cookie_string);
	}
	#画面出力
	my $hdrs = { "Set-Cookie" => \@set_cookies };
	$self->print_html($t, $hdrs);
}

1;
