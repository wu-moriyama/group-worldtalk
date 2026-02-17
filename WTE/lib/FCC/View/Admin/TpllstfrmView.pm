package FCC::View::Admin::TpllstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	#
	my @tmpl_loop;
	for my $tmpl ( @{$context->{tmpl_list}} ) {
		my $h = {};
		while( my($k, $v) = each %{$tmpl} ) {
			$h->{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		push(@tmpl_loop, $h);
	}
	$t->param("tmpl_loop" => \@tmpl_loop);
	#
	$self->print_html($t);
}

1;
