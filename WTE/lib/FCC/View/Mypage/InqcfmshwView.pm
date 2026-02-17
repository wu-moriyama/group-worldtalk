package FCC::View::Mypage::InqcfmshwView;
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
	my $captions = $context->{proc}->{captions};
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
		if($k eq "inq_cont") {
			my $ev = $v;
			$ev =~ s/\n/<br \/>/g;
			$t->param($k => $ev);
		} elsif($k =~ /^(inq_title)$/) {
			$t->param("${k}_caption" => CGI::Utils->new()->escapeHtml($captions->{"${k}_caption_${v}"}));
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
