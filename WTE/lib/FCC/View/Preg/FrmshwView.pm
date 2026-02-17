package FCC::View::Preg::FrmshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Preg::_SuperView);
use CGI::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#テンプレートのロード
	my $t = $self->load_template();
	#プリセット
	$t->param("pkey" => $context->{proc}->{pkey});
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^prof_(step|coupon_ok|status)$/) {
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} elsif($k =~ /^prof_(gender|reco)$/) {
			$t->param("${k}_${v}_checked" => 'checked="checked"');
		}
	}
	#特徴/興味
	for my $k ('prof_character', 'prof_interest') {
		my $v = $context->{proc}->{in}->{$k} + 0;
		my $bin = unpack("B32", pack("N", $v));
		my @bits = split(//, $bin);
		my @loop;
		for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
			my $title = $self->{conf}->{"${k}${id}_title"};
			my $checked = "";
			if($title eq "") { next; }
			if( $bits[-$id] ) {
				$checked = 'checked="checked"';
			}
			my $h = {
				id => $id,
				title => CGI::Utils->new()->escapeHtml($title),
				checked => $checked
			};
			push(@loop, $h);
		}
		$t->param("${k}_loop" => \@loop);
		$t->param("${k}_min" => $self->{conf}->{"${k}_min"});
		$t->param("${k}_max" => $self->{conf}->{"${k}_max"});
	}
	#ランク
	for my $k ('prof_rank') {
		my $v = $context->{proc}->{in}->{$k} + 0;
		my @loop;
		for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
			my $title = $self->{conf}->{"${k}${id}_title"};
			my $selected = "";
			if($title eq "") { next; }
			if( $id == $v ) {
				$selected = 'selected="selected"';
			}
			my $h = {
				id => $id,
				title => CGI::Utils->new()->escapeHtml($title),
				selected => $selected
			};
			push(@loop, $h);
		}
		$t->param("${k}_loop" => \@loop);
	}
	#出身国/居住国
	for my $k ('prof_country', 'prof_residence') {
		my @loop;
		for my $country (@{$context->{country_list}}) {
			my $country_code = $country->[0];
			my $country_name = $country->[1];
			my $selected = "";
			if($country_code eq $context->{proc}->{in}->{$k}) {
				$selected = 'selected="selected"';
			}
			my $h = {
				country_code => $country_code,
				country_name => CGI::Utils->new()->escapeHtml($country_name),
				selected => $selected
			};
			push(@loop, $h);
		}
		$t->param("${k}_loop" => \@loop);
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
	#sid用Cookie
	my $login_cookie_string = $self->{session}->login_cookie_string();
	#画面出力
	my $hdrs = { "Set-Cookie" => [$login_cookie_string] };
	$self->print_html($t, $hdrs);
}

1;
