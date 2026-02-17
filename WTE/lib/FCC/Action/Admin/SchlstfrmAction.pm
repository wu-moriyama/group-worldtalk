package FCC::Action::Admin::SchlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use Date::Pcalc;
use FCC::Class::Schedule;
use FCC::Class::Prof;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "schadd");
	unless($proc) {
		$proc = $self->create_proc_session_data("schadd");
		#講師識別IDを取得
		my $prof_id = $self->{q}->param("prof_id");
		if( ! defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#インスタンス
		my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db});
		#講師情報を取得
		my $prof = $oprof->get_from_db($prof_id);
		unless($prof) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{in} = {
			tm => []
		};
		$proc->{prof} = $prof;
		$self->set_proc_session_data($proc);
	}
	#指定日付を取得
	my $date = $self->{q}->param("d");
	#指定日を含む週の日付けリストを取得
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
	my $this_week_date_list;
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $ymd_s = "$tm[0]$tm[1]$tm[2]";
	my $available_datetime_e = $osch->get_available_datetime_e();
	my $ymd_e = substr($available_datetime_e, 0, 8);
	if($date) {
		if( $date =~ /^(\d{4})(\d{2})(\d{2})$/ ) {
			my $y = $1;
			my $m = $2;
			my $d = $3;
			if( ! Date::Pcalc::check_date($y, $m, $d) ) {
				$context->{fatalerrs} = ["不正なリクエストです。"];
				return $context;
			} else {
				$this_week_date_list = $osch->get_week_date_list($y, $m, $d);
				my $first_day = $this_week_date_list->[0]->{ymd};
				my $last_day = $this_week_date_list->[6]->{ymd};
				if( $last_day lt $ymd_s || $first_day gt $ymd_e ) {
					$context->{fatalerrs} = ["不正なリクエストです。"];
					return $context;
				}
			}
		} else {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
	} else {
		$this_week_date_list = $osch->get_week_date_list_from_epoch(time);
	}
	#登録済みのスケジュールを取得
	my $sd = $this_week_date_list->[0];
	my $ed = $this_week_date_list->[6];
	my $params = {
		prof_id => $self->{q}->param("prof_id"),
		sch_date_s => $sd->{Y} . $sd->{m} . $sd->{d},
		sch_date_e => $ed->{Y} . $ed->{m} . $ed->{d},
		offset => 0,
		limit => 9999
	};
	my $res = $osch->get_list($params);
	my $sch_hash = {};
	for my $r (@{$res->{list}}) {
		my($Y, $M, $D, $h, $m) = $r->{sch_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
		$sch_hash->{"${Y}${M}${D}${h}${m}"} = $r;
	}
	#来週の日付けリストを取得
	my $sdate = $this_week_date_list->[0];
	my $next_week_date_list = $osch->get_next_week_date_list($sdate->{Y}, $sdate->{n}, $sdate->{j});
	#先週の日付けリストを取得
	my $last_week_date_list = $osch->get_last_week_date_list($sdate->{Y}, $sdate->{n}, $sdate->{j});
	#今の日時(YYYYMMDDhhmm)
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $time_limit = "$tm[0]$tm[1]$tm[2]$tm[3]$tm[4]";
	#トークタイムのコマを取得
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($self->{q}->param("prof_id"));
	my $time_line_list = $osch->get_time_line($prof->{prof_step});
	my $time_lines = {};
	for my $d (@{$this_week_date_list}) {
		my $date = $d->{Y} . $d->{m} . $d->{d};
		my @list;
		for my $tl (@{$time_line_list}) {
			my $h = {};
			$h->{sh} = $tl->[0];
			$h->{sm} = $tl->[1];
			$h->{eh} = $tl->[2];
			$h->{em} = $tl->[3];
			my $dt = $date . sprintf("%02d", $tl->[0]) . sprintf("%02d", $tl->[1]);
			$h->{disabled} = $osch->is_available_datetime($dt) ? "" : "disabled";
			if( $sch_hash->{$dt} ) {
				while( my($k, $v) = each %{$sch_hash->{$dt}} ) {
					$h->{$k} = $v;
				}
			}
			push(@list, $h);
		}
		$time_lines->{$date} = \@list;
	}
	#
	my $last_week_disabled = ($ymd_s le $last_week_date_list->[6]->{ymd}) ? "" : "disabled";
	my $next_week_disabled = ($ymd_e ge $next_week_date_list->[0]->{ymd}) ? "" : "disabled";
	#
	$context->{this_week_date_list} = $this_week_date_list;
	$context->{next_week_date_list} = $next_week_date_list;
	$context->{last_week_date_list} = $last_week_date_list;
	$context->{time_lines} = $time_lines;
	$context->{last_week_disabled} = $last_week_disabled;
	$context->{next_week_disabled} = $next_week_disabled;
	$context->{this_week_first_date} = $this_week_date_list->[0]->{ymd};
	$context->{proc} = $proc;
	return $context;
}

1;
