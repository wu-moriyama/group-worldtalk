package FCC::View::Prof::BilpdmfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);
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
	$t->param("pkey" => $context->{proc}->{pkey});
	#検索結果の一覧
	my $res = $context->{res};
	my @list_loop;
	my $epoch = time;
	my $in = $context->{proc}->{in};
	for my $ref (@{$in->{lsn_list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^(prof_cdate|prof_mdate)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k =~ /^prof_(gender|status|card|reco|coupon_ok)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k eq "prof_rank") {
				my $title = $self->{conf}->{"prof_rank${v}_title"};
				$hash{"${k}_title"} = CGI::Utils->new()->escapeHtml($title);
			} elsif($k =~ /^lsn_(cancelable|prof_repo|member_repo|member_repo_rating|status|pdm_status)$/) {
				$hash{"${k}_${v}"} = 1;
			} elsif($k =~ /_(fee|price)$/) {
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
	#合計額
	$t->param("pdm_demand_ok" => $in->{pdm_demand_ok});
	$t->param("pdm_price" => $in->{pdm_price});
	$t->param("pdm_price_with_comma" => FCC::Class::String::Conv->new($in->{pdm_price})->comma_format());
	#
	my $pdm_min_price = $self->{conf}->{pdm_min_price};
	$t->param("pdm_min_price" => $in->{pdm_min_price});
	$t->param("pdm_min_price_with_comma" => FCC::Class::String::Conv->new($pdm_min_price)->comma_format());
	#
	$self->print_html($t);
}

1;
