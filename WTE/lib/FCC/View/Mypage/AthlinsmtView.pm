package FCC::View::Mypage::AthlinsmtView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Cookie;
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	#入力値エラーの評価
	if($context->{errs}) {
		#ログオン失敗

		my $lang = '';
		my %cookies = fetch CGI::Cookie;
		if($cookies{'member_lang'}) {
			$lang = $cookies{'member_lang'}->value;
		}

		#ログオンフォームを再表示
		my $t = $self->load_template("$self->{conf}->{TEMPLATE_DIR}/Athlinfrm.html", undef, $lang);
		while( my($k, $v) = each %{$context->{seller}} ) {
			if( ! defined $v ) { $v = ""; }
			$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
		while( my($k, $v) = each %{$context->{in}} ) {
			$t->param($k => CGI::Utils->new()->escapeHtml($v));
			if($k eq "auto_login_enable") {
				$t->param("${k}_${v}_checked" => 'checked="checked"');
			}
		}
		#エラーメッセージ
		my $errs = "<ul>";
		for my $e (@{$context->{errs}}) {
			$t->param("$e->[0]_err" => "err");
			$errs .= "<li>$e->[1]</li>";
		}
		$errs .= "</ul>";
		$t->param('errs' => $errs);
		#
		$self->print_html($t);
	} else {
		#ログオン成功
		#ログオン中...画面へリダイレクト
		my $t = $self->load_template();
		$t->param('epoch' => time);
		if( $context->{redirect} ) {
			$t->param("redirect" => $context->{redirect});
		} else {
			$t->param("target" => $context->{target});
		}
		$t->param("session_seller_fqdn" => $context->{seller}->{seller_fqdn});
		#sid用Cookie
		my $login_cookie_string = $self->{session}->login_cookie_string();
		my @set_cookies = ($login_cookie_string);
		if($context->{in}->{auto_login_enable} eq "1") {
			#auto_logon_enable用Cookie
			my $auto_login_cookie_string = $self->{session}->auto_login_cookie_string();
			push(@set_cookies, $auto_login_cookie_string);
		}

		#表示言語のCookie
		{
			my $cookie = new CGI::Cookie(
				-name    => 'member_lang',
				-value   => $context->{member}->{member_lang},
				-path    => $self->{conf}->{CGI_DIR_URL_PATH},
				-expires => '+1y',
				-secure  => 1
			);
			my $cookie_string = $cookie->as_string();
			push(@set_cookies, $cookie_string);
		}

		#画面出力
		my $hdrs = { "Set-Cookie" => \@set_cookies };
		$self->print_html($t, $hdrs);
	}
}

1;
