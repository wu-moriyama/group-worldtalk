package FCC::View::Admin::DctlstfrmView;
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
	#
	my $pkey =  $context->{proc}->{pkey};
	#テンプレートのロード
	my $t = $self->load_template();
	#検索結果の一覧
	my @list_loop;
	for my $ref (@{$context->{list}}) {
		my %hash;
		while( my($k, $v) = each %{$ref} ) {
			$hash{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k eq "dct_status") {
				$hash{"${k}_${v}"} = 1;
			} elsif($k =~ /^dct_items$/) {
				$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{pkey} = $pkey;
		push(@list_loop, \%hash);
	}
	$t->param("list_loop" => \@list_loop);
	#
	my $hit = scalar @{$context->{list}};
	$t->param("hit" => $hit);
	#
	$self->print_html($t);
}

1;
