package FCC::View::Admin::AuthinitView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#不正アクセスエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#入力値エラーの評価
	if($context->{errs}) {
		my $t = $self->load_template("$self->{conf}->{TEMPLATE_DIR}/Authinitform.html");
		while( my($k, $v) = each %{$context->{in}} ) {
			$t->param($k => $v);
		}
		my $errs = "<ul>";
		for my $e (@{$context->{errs}}) {
			$errs .= "<li>${e}</li>";
		}
		$errs .= "</ul>";
		$t->param('errs' => $errs);
		$self->print_html($t);
	} else {
		#パスワード設定完了画面へリダイレクト
		my $url = $self->{conf}->{CGI_URL} . "?m=authinitok";
		print "Location: ${url}\n\n";
		exit;
	}
}

1;
