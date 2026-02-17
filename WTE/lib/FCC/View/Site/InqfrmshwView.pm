package FCC::View::Site::InqfrmshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Site::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	#会員ログイン済みなら会員メニューへリダイレクト
	if( $context->{redirect} ) {
		my $url = $context->{redirect};
		print "Location: ${url}\n\n";
		return;
	}
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $in = $context->{proc}->{in};
	my $member = $context->{proc}->{member};
	#テンプレートのロード
	my $t = $self->load_template();
	$t->param("pkey" => $context->{proc}->{pkey});
	#
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^(inq_mtype|inq_title)$/) {
			$t->param("${k}_checked_${v}" => "checked");
			$t->param("${k}_selected_${v}" => "selected");
		}
	}
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
