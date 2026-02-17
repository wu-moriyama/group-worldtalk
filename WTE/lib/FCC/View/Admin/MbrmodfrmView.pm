package FCC::View::Admin::MbrmodfrmView;
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
		if($k =~ /^(member_cdate|member_mdate)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
		} elsif($k eq "member_status") {
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} elsif($k =~ /^member_(gender|lang)$/) {
			$t->param("${k}_${v}_checked" => 'checked="checked"');
		} elsif($k =~ /^member_(point|coupon)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		} elsif($k eq "member_note") {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		}
	}
	#代理店情報
	while( my($k, $v) = each %{$context->{proc}->{seller}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^(seller_cdate|seller_mdate)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$t->param("${k}_${i}" => $tm[$i]);
			}
		} elsif($k eq "seller_status") {
			$t->param("${k}_${v}" => 1);
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
	#目的/希望/興味/レベル・属性
	for my $k ('member_purpose', 'member_demand', 'member_interest', 'member_level') {
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
	#その他
	$t->param("epoch" => time);
	for( my $i=1; $i<=3; $i++ ) {
		$t->param("member_logo_${i}_w" => $self->{conf}->{"member_logo_${i}_w"});
		$t->param("member_logo_${i}_h" => $self->{conf}->{"member_logo_${i}_h"});
	}
	#
	$self->print_html($t);
}

1;
