package FCC::View::Mypage::ActlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
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
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	my $epoch = time;
	for my $ref (@{$res->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "mbract_cdate") {
				my %fmt = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get_formated();
				while( my($fn, $fv) = each %fmt ) {
					$hash{"${k}_${fn}"} = $fv;
				}
			} elsif($k =~ /^mbract_(type|reason)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k eq "mbract_price") {
				$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
		push(@list_loop, \%hash);
	}
	$t->param("list_loop" => \@list_loop);
	#ページナビゲーション
	my @navi_params = ('hit', 'fetch', 'start', 'end', 'next_num', 'prev_num');
	for my $k (@navi_params) {
		my $v = $res->{$k};
		$t->param($k => $v);
		$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
	}
	$t->param("next_url" => $res->{next_url});
	$t->param("prev_url" => $res->{prev_url});
	#ページナビゲーション
	$t->param("page_loop" => $res->{page_list});
	#現在の保持ポイントと有効期限
	while( my($k, $v) = each %{$context->{member}} ) {
		if($k =~ /^member_(point|coupon)$/) {
			$t->param($k => $v);
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		} elsif($k =~ /^member_(point|coupon)_expire$/) {
			my($y, $m, $d) = split(/\-/, $v);
			$m += 0;
			$d += 0;
			$t->param("${k}_y" => $y);
			$t->param("${k}_m" => $m);
			$t->param("${k}_d" => $d);
		}
	}
	#
	while( my($k, $v) = each %{$context->{auto}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
		if($k =~ /^auto_(point|price)$/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	#
	$self->print_html($t);
}

1;
