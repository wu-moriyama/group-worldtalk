package FCC::View::Mypage::SchlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	$t->param("pkey" => $context->{proc}->{pkey});
	#ナビゲーション
	for my $type ("last", "this", "next") {
		while( my($k, $v) = each %{$context->{"${type}_month"}} ) {
			$t->param("${type}_month_${k}" => $v);
		}
	}
	$t->param("last_month_disabled" => $context->{last_month_disabled});
	$t->param("next_month_disabled" => $context->{next_month_disabled});
	#カレンダー
	my $lessons = $context->{lessons};
	my @week_loop;
	for my $week (@{$context->{this_month_date_list}}) {
		my @day_loop;
		for my $d (@{$week}) {
			my $h = {};
			while( my($k, $v) = each %{$d} ) {
				$h->{$k} = $v;
			}
			my $date = $d->{Y} . $d->{m} . $d->{d};
			$h->{lsn_num} = 0;
			if($lessons->{$date}) {
				my @lsn_loop;
				for my $lsn (@{$lessons->{$date}}) {
					my $lsnh = {};
					while( my($k, $v) = each %{$lsn} ) {
						$lsnh->{$k} = CGI::Utils->new()->escapeHtml($v);
					}
					$lsnh->{CGI_URL} = $self->{conf}->{CGI_URL};
					push(@lsn_loop, $lsnh);
				}
				$h->{lsn_loop} = \@lsn_loop;
				$h->{lsn_num} = scalar @{$lessons->{$date}};
			}
			$h->{CGI_URL} = $self->{conf}->{CGI_URL};
			push(@day_loop, $h);
		}
		push(@week_loop, { day_loop => \@day_loop });
	}
	$t->param("week_loop" => \@week_loop);
	#
	$t->param("ym" => $context->{ym});
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
	#
	$self->print_html($t);
}

1;
