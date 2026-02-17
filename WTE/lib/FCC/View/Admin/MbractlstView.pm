package FCC::View::Admin::MbractlstView;
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
			if($k =~ /^(mbract_cdate|mbract_mdate)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k =~ /^(mbract_type|mbract_reason)$/) {
				$hash{"${k}_${v}"} = 1;
			}
		}
		if($ref->{mbract_type} == 1) {
			$hash{mbract_price_1} = abs($ref->{mbract_price});
			$hash{mbract_price_1_with_comma} = FCC::Class::String::Conv->new($hash{mbract_price_1})->comma_format();
		} elsif($ref->{mbract_type} == 2) {
			$hash{mbract_price_2} = abs($ref->{mbract_price});
			$hash{mbract_price_2_with_comma} = FCC::Class::String::Conv->new($hash{mbract_price_2})->comma_format();
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
	$t->param("next_url" => $res->{next_url});
	$t->param("prev_url" => $res->{prev_url});
	#ページナビゲーション
	$t->param("page_loop" => $res->{page_list});
	#検索条件
	while( my($k, $v) = each %{$res->{params}} ) {
		if($k =~ /^(member_id|cdate1|cdate2)$/) {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
		} elsif($k =~ /^(limit)$/) {
			$t->param($k => $v);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		}
	}
	#検索対象の会員情報
	if( defined $res->{member} && ref($res->{member}) eq "HASH" ) {
		while( my($k, $v) = each %{$res->{member}} ) {
			$t->param("ajax_${k}" => CGI::Utils->new()->escapeHtml($v));
		}
	}
	#CSVダウンロードURL
	$t->param("download_url" => $res->{download_url});
	#
	$self->print_html($t);
}

1;
