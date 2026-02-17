package FCC::View::Admin::AuthlogonformView;
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
	my $t = $self->load_template();
	$t->param('auto_logon' => $self->{conf}->{auto_logon});
	$self->print_html($t);
}

1;
