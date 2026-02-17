package FCC::View::Admin::MbrchgfrmView;
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
	$t->param("mbract_price" => $in->{mbract_price});
	$t->param("mbract_reason_$in->{mbract_reason}_selected" => 'selected="selected"');
	$t->param("member_point_expire_update" => $in->{member_point_expire_update});
	while( my($k,$v) = each %{$in} ) {
		$t->param("ajax_${k}" => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^(member_point|member_receivable_point|member_available_point)$/) {
			$t->param("ajax_${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		} elsif($k eq "expire_not_update") {
			$t->param("${k}_${v}_checked" => 'checked="checked"');
		}
	}
	#
	$t->param("coupon_expire_days" => $self->{conf}->{coupon_expire_days});
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
