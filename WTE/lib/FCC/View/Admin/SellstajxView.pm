package FCC::View::Admin::SellstajxView;
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
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	for my $ref (@{$res->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^(seller_cdate|seller_mdate)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash{"${k}_${i}"} = $tm[$i];
				}
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
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
	#検索条件
	while( my($k, $v) = each %{$res->{params}} ) {
		if($k =~ /^(seller_id|seller_company|seller_email)$/) {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
		} elsif($k eq "seller_status") {
			$t->param("s_${k}_${v}_selected" => 'selected="selected"');
		} elsif($k eq "limit") {
			$t->param($k => $v);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		}
	}
	#
	$t->param("limit_over" => $res->{limit_over});
	#
	$self->print_html($t);
}

1;
