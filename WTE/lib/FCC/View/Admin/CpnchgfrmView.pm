package FCC::View::Admin::CpnchgfrmView;
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
	#プリセット
	$t->param("pkey" => $context->{proc}->{pkey});
	my $in = $context->{proc}->{in};
	$t->param("member_id" => $in->{member_id});
	$t->param("cpnact_price" => $in->{cpnact_price});
	$t->param("cpnact_type_$in->{cpnact_type}_selected" => 'selected="selected"');
	while( my($k,$v) = each %{$in} ) {
		$t->param("ajax_${k}" => CGI::Utils->new()->escapeHtml($v));
		if($k eq "member_coupon") {
			$t->param("ajax_${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
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
	#
	$self->print_html($t);
}

1;
