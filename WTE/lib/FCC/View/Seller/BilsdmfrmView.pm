package FCC::View::Seller::BilsdmfrmView;
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
			if($k =~ /^lsn_(sdm_status|status)$/) {
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
	$t->param("sdm_demand_ok" => $in->{sdm_demand_ok});
	$t->param("sdm_price" => $in->{sdm_price});
	$t->param("sdm_price_with_comma" => FCC::Class::String::Conv->new($in->{sdm_price})->comma_format());
	#
	my $sdm_min_price = $self->{conf}->{sdm_min_price};
	$t->param("sdm_min_price" => $in->{sdm_min_price});
	$t->param("sdm_min_price_with_comma" => FCC::Class::String::Conv->new($sdm_min_price)->comma_format());
	#
	$self->print_html($t);
}

1;
