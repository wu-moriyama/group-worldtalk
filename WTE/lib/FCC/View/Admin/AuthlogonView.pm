package FCC::View::Admin::AuthlogonView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Cookie;

sub dispatch {
	my($self, $context) = @_;
	#入力値エラーの評価
	if($context->{errs}) {
		#ログオン失敗
		#ログオンフォームを再表示
		my $t = $self->load_template("$self->{conf}->{TEMPLATE_DIR}/Authlogonform.html");
		while( my($k, $v) = each %{$context->{in}} ) {
			$t->param($k => $v);
		}
		my $errs = "<ul>";
		for my $e (@{$context->{errs}}) {
			$errs .= "<li>${e}</li>";
		}
		$errs .= "</ul>";
		$t->param('errs' => $errs);
		$t->param('auto_logon' => $self->{conf}->{auto_logon});
		$self->print_html($t);
	} else {
		#ログオン成功
		#ログオン中...画面へリダイレクト
		my $t = $self->load_template();
		$t->param('epoch' => time);
		if($context->{auto_logon_enable} eq "1") {
			#sid用Cookie
			my $cs = new CGI::Cookie(
				-name    =>  "$self->{conf}->{FCC_SELECTOR}_sid",
				-value   =>  "$context->{sid}",
				-expires =>  "+$self->{conf}->{session_expire}h",
				-path    =>  $self->{conf}->{CGI_DIR_URL_PATH}
			);
			my $cs_string = $cs->as_string;
			$t->param("cookie_string_sid" => $cs_string);
			#auto_logon_enable用Cookie
			my $ca = new CGI::Cookie(
				-name    =>  "$self->{conf}->{FCC_SELECTOR}_auto_logon_enable",
				-value   =>  "1",
				-expires =>  "+$self->{conf}->{session_expire}h",
				-path    =>  $self->{conf}->{CGI_DIR_URL_PATH}
			);
			my $ca_string = $ca->as_string;
			$t->param("cookie_string_auto_logon_enable" => $ca_string);
			#画面出力
			my $hdrs = { "Set-Cookie" => [$cs_string, $ca_string] };
			$self->print_html($t, $hdrs);
		} else {
			my $cs = new CGI::Cookie(
				-name    =>  "$self->{conf}->{FCC_SELECTOR}_sid",
				-value   =>  "$context->{sid}",
				-path    =>  $self->{conf}->{CGI_DIR_URL_PATH}
			);
			my $cs_string = $cs->as_string;
			$t->param("cookie_string_sid" => $cs_string);
			#画面出力
			my $hdrs = { "Set-Cookie" => $cs_string };
			$self->print_html($t, $hdrs);
		}
	}
}

1;
