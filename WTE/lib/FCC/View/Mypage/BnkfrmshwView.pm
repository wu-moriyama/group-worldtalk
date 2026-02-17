package FCC::View::Mypage::BnkfrmshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
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
	while( my($k, $v) = each %{$member} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k eq "point") {
			$t->param("${k}_${v}" => 'selected="selected"');
		}
	}
	#
	my @plan_loop;
	for my $pln (@{$context->{plan_list}}) {
		if($pln->{pln_subscription} == 1) { next; }
		my %h;
		while( my($k, $v) = each %{$pln} ) {
			if( ! defined $v ) { $v = ""; }
			$h{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /_(point|price)/) {
				$h{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
		}
		if($pln->{pln_id} eq $in->{pln_id}) {
			$h{selected} = 'selected="selected"';
			$h{checked} = 'checked="checked"';
		}
		push(@plan_loop, \%h);
	}
	$t->param("plan_loop" => \@plan_loop);
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
