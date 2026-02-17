package FCC::View::Admin::SchlstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	$t->param("pkey" => $context->{proc}->{pkey});
	#講師情報
	while( my($k, $v) = each %{$context->{proc}->{prof}} ) {
		if( ! defined $v ) { $v = ""; }
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	#ナビゲーション
	for my $type ("last", "this", "next") {
		#週の開始日（日曜日）
		my $week_sdate = $context->{"${type}_week_date_list"}->[0];
		while( my($k, $v) = each %{$week_sdate} ) {
			$t->param("${type}_week_s_${k}" => $v);
		}
		#週の終了日（土曜日）
		my $week_edate = $context->{"${type}_week_date_list"}->[6];
		while( my($k, $v) = each %{$week_edate} ) {
			$t->param("${type}_week_e_${k}" => $v);
		}
	}
	$t->param("last_week_disabled" => $context->{last_week_disabled});
	$t->param("next_week_disabled" => $context->{next_week_disabled});
	#表のヘッダー（日付・曜日）
	my @date_week_loop;
	for my $dt (@{$context->{this_week_date_list}}) {
		push(@date_week_loop, $dt);
	}
	$t->param("date_week_loop" => \@date_week_loop);
	#表のボディー
	my $time_line_date_loops = {};
	for my $dt (@{$context->{this_week_date_list}}) {
#		my $date = $dt->{Y} . $dt->{m} . $dt->{d};
		my $date = $dt->{ymd};
		my $time_line_list = $context->{time_lines}->{$date};
		my $time_line_loops = {};
		for my $tl (@{$time_line_list}) {
			my $time_range_code = int($tl->{sh} / 4) + 1;
			unless($time_line_loops->{$time_range_code}) {
				$time_line_loops->{$time_range_code} = [];
			}
			my $h = {
				stime    => $tl->{sh} . ":" . sprintf("%02d", $tl->{sm}),
				etime    => $tl->{eh} . ":" . sprintf("%02d", $tl->{em}),
				v        => $date . sprintf("%02d", $tl->{sh}) . sprintf("%02d", $tl->{sm}),
				disabled => $tl->{disabled}
			};
			while( my($k, $v) = each %{$dt} ) {
				$h->{$k} = $v;
			}
			while( my($k, $v) = each %{$tl} ) {
				$h->{$k} = $v;
			}
			push(@{$time_line_loops->{$time_range_code}}, $h);
		}
		while( my($code, $ary) = each %{$time_line_loops} ) {
			my $h = {
				time_line_loop => $ary,
				disabled       => $dt->{disabled}
			};
			while( my($k, $v) = each %{$dt} ) {
				$h->{$k} = $v;
			}
			push(@{$time_line_date_loops->{$code}}, $h);
		}
	}
	while( my($i, $loop) = each %{$time_line_date_loops} ) {
		$t->param("time_line_date_loop_${i}" => $loop);
	}
	#
	$t->param("d" => $context->{this_week_first_date});
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
