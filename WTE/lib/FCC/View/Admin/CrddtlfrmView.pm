package FCC::View::Admin::CrddtlfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	my $proc = $context->{proc};

	#テンプレートのロード
	my $t = $self->load_template();
	$t->param("pkey" => $proc->{pkey});
	#プリセット
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		if($k =~ /^crd_(subscription|ref|success)$/) {
			$t->param("${k}_${v}" => 1);
			$t->param($k => $v);
		} elsif($k =~ /^crd_(price|point)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		} else {
			$v = CGI::Utils->new()->escapeHtml($v);
			$v =~ s/\n/<br \/>/g;
			$t->param($k => $v);
		}
	}
	#
	$self->print_html($t);
}

1;
