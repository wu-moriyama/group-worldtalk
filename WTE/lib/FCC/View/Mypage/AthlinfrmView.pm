package FCC::View::Mypage::AthlinfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	#不正アクセスエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#テンプレートをロード
	my $lang = $context->{lang};
	my $t = $self->load_template(undef, undef, $lang);
	#
	while( my($k, $v) = each %{$context->{seller}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
	}
	$t->param("target" => $context->{target});
	$t->param("redirect" => CGI::Utils->new()->escapeHtml($context->{redirect}));
	#
	my $secure = 0;
	if($self->{conf}->{CGI_DIR_URL} =~ /^https/i) { $secure = 1; }
	my $ctest = new CGI::Cookie(
		-name    =>  "test",
		-value   =>  "1",
		-path    =>  $self->{conf}->{CGI_DIR_URL_PATH},
		-secure  => $secure
	);
	my $ctest_string = $ctest->as_string;
	$t->param("cookie_string_test" => $ctest_string);
	my $hdrs = { "Set-Cookie" => $ctest_string };
	$self->print_html($t, $hdrs);
}

1;
