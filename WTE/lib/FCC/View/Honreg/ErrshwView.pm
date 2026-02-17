package FCC::View::Honreg::ErrshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Honreg::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	#置換
	while( my($k, $v) = each %{$context->{seller}} ) {
		$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
	}
	$t->param("err" => CGI::Utils->new()->escapeHtml($context->{err}));
	#画面出力
	$self->print_html($t);
}

1;
