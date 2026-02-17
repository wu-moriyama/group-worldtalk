package FCC::View::Seller::SdmlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Seller::_SuperView);
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
			if($k =~ /^sdm_(cdate)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k =~ /^sdm_(status)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k =~ /^sdm_(price)$/) {
				$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
		$hash{member_caption} = $self->{conf}->{member_caption};
		$hash{prof_caption} = $self->{conf}->{prof_caption};
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
	#
	$self->print_html($t);
}

1;
