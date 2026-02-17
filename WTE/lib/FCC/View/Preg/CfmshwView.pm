package FCC::View::Preg::CfmshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Preg::_SuperView);
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#プロセスキー
	my $pkey = $context->{proc}->{pkey};
	#
	#テンプレートのロード
	my $t = $self->load_template();
	#プリセット
	$t->param("pkey" => $context->{proc}->{pkey});
	while( my($k, $v) = each %{$context->{proc}->{in}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k eq "prof_pass") {
			$t->param("${k}_mask" => '*' x length($v));
		} elsif($k =~ /^prof_(gender|status|card|reco|coupon_ok)$/) {
			$t->param("${k}_${v}" => 1);
		} elsif($k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note|app\d)$/) {
			my $tmp = CGI::Utils->new()->escapeHtml($v);
			$tmp =~ s/\n/<br \/>/g;
			$t->param($k => $tmp);
		} elsif($k eq "prof_rank") {
			my $title = $self->{conf}->{"prof_rank${v}_title"};
			$t->param("${k}_title" => CGI::Utils->new()->escapeHtml($title));
		} elsif($k eq "prof_fee") {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		} elsif($k =~ /^prof_(country|residence)$/) {
			$t->param("${k}_name" => CGI::Utils->new()->escapeHtml($context->{country_hash}->{$v}));
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
			unless( $bits[-$id] ) { next; }
			my $h = {
				id => $id,
				title => CGI::Utils->new()->escapeHtml($title)
			};
			push(@loop, $h);
		}
		$t->param("${k}_loop" => \@loop);
	}
	#画面出力
	$self->print_html($t);
}

1;
