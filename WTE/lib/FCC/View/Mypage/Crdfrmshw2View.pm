package FCC::View::Mypage::Crdfrmshw2View;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $in = $context->{proc}->{in};
	#テンプレートのロード
	my $t = $self->load_template();
	$t->param("pkey" => $context->{proc}->{pkey});
	#
	my @plan_loop;
	my @plan_loop_1;
	my @plan_loop_0;
	for my $pln (@{$context->{plan_list}}) {
		my %h;
		while( my($k, $v) = each %{$pln} ) {
			if( ! defined $v ) { $v = ""; }
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^pln_(price|point)$/) {
				$h{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
		}
		if($pln->{pln_id} eq $in->{pln_id}) {
			$h{selected} = 'selected="selected"';
			$h{checked} = 'checked="checked"';
		}
		push(@plan_loop, \%h);
		if($pln->{pln_subscription} == 1) {
			push(@plan_loop_1, \%h);
		} elsif($pln->{pln_subscription} == 0) {
			push(@plan_loop_0, \%h);
		}
	}
	$t->param("plan_loop" => \@plan_loop);
	$t->param("plan_loop_1" => \@plan_loop_1);
	$t->param("plan_loop_0" => \@plan_loop_0);
	#
	while( my($k, $v) = each %{$context->{auto}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^auto_(point|price)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
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
