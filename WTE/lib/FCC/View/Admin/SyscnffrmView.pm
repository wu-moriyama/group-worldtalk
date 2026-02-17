package FCC::View::Admin::SyscnffrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	$t->param("pkey" => $context->{proc}->{pkey});
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	$t->param("REMOTE_ADDR" => $ENV{REMOTE_ADDR});
	#プロセスエラー
	if( @{$context->{proc}->{errs}} ) {
		my $errs = "<ul>";
		for my $e (@{$context->{proc}->{errs}}) {
			$t->param("$e->[0]_err" => "err");
			$errs .= "<li>$e->[1]</li>";
		}
		$errs .= "</ul>";
		$t->param('errs' => $errs);
	}
	#データのプリセット
	if($context->{proc}->{in} && ref($context->{proc}->{in}) eq "HASH") {
		while( my($k, $v) = each %{$context->{proc}->{in}} ) {
			if( ! defined $v ) { $v = ""; }
			$t->param($k => CGI::Utils->new()->escapeHtml($v));
			if($k eq "auto_logon") {
				if($v eq "1") {
					$t->param("${k}_checked" => 'checked="checked"');
				}
			}
		}
	}
	#タイムゾーン
	if($context->{proc}->{tz_loop} && ref($context->{proc}->{tz_loop}) eq "ARRAY") {
		my @tz_loop;
		for my $tz (sort @{$context->{proc}->{tz_loop}}) {
			my %hash;
			$hash{tz} = CGI::Utils->new()->escapeHtml($tz);
			if($context->{proc}->{in}->{tz} && $tz eq $context->{proc}->{in}->{tz}) {
				$hash{selected} = 'selected="selected"';
			}
			push(@tz_loop, \%hash);
		}
		$t->param("tz_loop" => \@tz_loop);
	}
	#
	$self->print_html($t);
}

1;
