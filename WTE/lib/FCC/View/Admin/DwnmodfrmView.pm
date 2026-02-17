package FCC::View::Admin::DwnmodfrmView;
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
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k eq "dwn_pubdate") {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
		} elsif($k =~ /^dwn_(status)$/) {
			$t->param("${k}_${v}_selected" => 'selected="selected"');
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^dwn_(type|loc)$/) {
			$t->param("${k}_${v}" => 1);
		}
	}
	#カテゴリー一覧
	my @dct_loop;
	for my $ref (@{$context->{dct_list}}) {
		my $h = {};
		while( my($k, $v) = each %{$ref} ) {
			$h->{$k} = CGI::Utils->new()->escapeHtml($v);
		}
		if($ref->{dct_id} == $context->{proc}->{in}->{dct_id}) {
			$h->{selected} = 'selected="selected"';
		}
		push(@dct_loop, $h);
	}
	$t->param("dct_loop" => \@dct_loop);
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
		$t->param("dwn_logo_${i}_w" => $self->{conf}->{"dwn_logo_${i}_w"});
		$t->param("dwn_logo_${i}_h" => $self->{conf}->{"dwn_logo_${i}_h"});
	}
	#
	$self->print_html($t);
}

1;
