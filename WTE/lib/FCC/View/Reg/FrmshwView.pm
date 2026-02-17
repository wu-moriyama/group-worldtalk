package FCC::View::Reg::FrmshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Reg::_SuperView);
use CGI::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	#プリセット
	$t->param("pkey" => $context->{proc}->{pkey});
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	$t->param("hon_point_add_with_comma" => FCC::Class::String::Conv->new($self->{conf}->{hon_point_add})->comma_format());
	#プロセスエラー
	if( defined $context->{proc}->{errs} && @{$context->{proc}->{errs}} ) {
		my $errs = "<ul>";
		for my $e (@{$context->{proc}->{errs}}) {
			$t->param("$e->[0]_err" => "err");
			$errs .= "<li>$e->[1]</li>";
		}
		$errs .= "</ul>";
		$t->param('errs' => $errs);
	}
	#sid用Cookie
	my $login_cookie_string = $self->{session}->login_cookie_string();
	#画面出力
	my $hdrs = { "Set-Cookie" => [$login_cookie_string] };
	$self->print_html($t, $hdrs);
}

1;
