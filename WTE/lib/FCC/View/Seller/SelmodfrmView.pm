package FCC::View::Seller::SelmodfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Seller::_SuperView);
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
	#プリセット
	$t->param("pkey" => $context->{proc}->{pkey});
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^(seller_cdate|seller_mdate|seller_yahoo_date|seller_google_date)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
		} elsif($k =~ /^seller_(status)$/) {
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} elsif($k eq "seller_pay") {
			$t->param("${k}_${v}_checked" => 'checked="checked"');
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
	#その他
	$t->param("epoch" => time);
	for( my $i=1; $i<=3; $i++ ) {
		$t->param("seller_logo_${i}_w" => $self->{conf}->{"seller_logo_${i}_w"});
		$t->param("seller_logo_${i}_h" => $self->{conf}->{"seller_logo_${i}_h"});
	}
	#
	$self->print_html($t);
}

1;
