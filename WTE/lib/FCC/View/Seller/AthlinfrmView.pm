package FCC::View::Seller::AthlinfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Seller::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#不正アクセスエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#テンプレートをロード
	my $t = $self->load_template();
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
