package FCC::View::Site::PrfschajxView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Site::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	#ナビゲーション
	for my $type ("last", "this", "next") {
		while( my($k, $v) = each %{$context->{"${type}_month"}} ) {
			$t->param("${type}_month_${k}" => $v);
		}
	}
	$t->param("last_month_disabled" => $context->{last_month_disabled});
	$t->param("next_month_disabled" => $context->{next_month_disabled});
	#カレンダー
	my $schs = $context->{schs};
	my @week_loop;
	for my $week (@{$context->{this_month_date_list}}) {
		my @day_loop;
		for my $d (@{$week}) {
			my $h = {};
			while( my($k, $v) = each %{$d} ) {
				$h->{$k} = $v;
			}
			my $date = $d->{Y} . $d->{m} . $d->{d};
			$h->{sch_num} = 0;
			if($schs->{$date}) {
				$h->{sch_loop} = $schs->{$date};
				for my $sch (@{$h->{sch_loop}}) {
					$sch->{CGI_URL} = $self->{conf}->{CGI_URL};
				}
				$h->{sch_num} = scalar @{$schs->{$date}};
			}
			$h->{CGI_URL} = $self->{conf}->{CGI_URL};
			push(@day_loop, $h);
		}
		push(@week_loop, { day_loop => \@day_loop });
	}
	$t->param("week_loop" => \@week_loop);
	#講師情報
	while( my($k, $v) = each %{$context->{prof}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	#
	$t->param("ym" => $context->{ym});
	#
	$self->print_html($t);
}

1;
