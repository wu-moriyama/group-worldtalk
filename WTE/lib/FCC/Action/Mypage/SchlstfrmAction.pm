package FCC::Action::Mypage::SchlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use Date::Pcalc;
use FCC::Class::Schedule;
use FCC::Class::Lesson;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "schadd");
	unless($proc) {
		$proc = $self->create_proc_session_data("schadd");
		$proc->{in} = {
			tm => []
		};
		$self->set_proc_session_data($proc);
	}
	#指定年月を取得
	my $ym = $self->{q}->param("ym");
	#指定年月の日付けリストを取得
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
	my $this_month_date_list;
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $ym_s = "$tm[0]$tm[1]";
	my $available_datetime_e = $osch->get_available_datetime_e();
	my $ym_e = substr($available_datetime_e, 0, 6);
	if($ym) {
		if( $ym =~ /^(\d{4})(\d{2})$/ ) {
			my $y = $1;
			my $m = $2;
			if( Date::Pcalc::check_date($y, $m, 1) ) {
				if( $ym lt $ym_s || $ym gt $ym_e ) {
					$context->{fatalerrs} = ["不正なリクエストです。(1)"];
					return $context;
				}
				$this_month_date_list = $osch->get_month_date_list($y, $m);
			} else {
				$context->{fatalerrs} = ["不正なリクエストです。(2)"];
				return $context;
			}
		} else {
			$context->{fatalerrs} = ["不正なリクエストです。(3)"];
			return $context;
		}
	} else {
		$this_month_date_list = $osch->get_month_date_list_from_epoch(time);
	}
	my $dt = $this_month_date_list->[1]->[0];
	$ym = $dt->{Y} . $dt->{m};
	#登録済みのレッスンを取得
	my $sd = $this_month_date_list->[0]->[0];
	my $week_num = @{$this_month_date_list};
	my $ed = $this_month_date_list->[$week_num-1]->[6];
	my $params = {
		member_id   => $member_id,
		lsn_stime_s => $sd->{Y} . $sd->{m} . $sd->{d},
		lsn_stime_e => $ed->{Y} . $ed->{m} . $ed->{d},
		lsn_cancel  => 0,
		offset      => 0,
		limit       => 9999,
		sort => [["lsn_stime", "ASC"]]
	};
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $res = $olsn->get_list($params);
	my $lessons = {};
	for my $r (@{$res->{list}}) {
		my($Y, $M, $D, $h, $m) = $r->{lsn_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})/;
		my $date = "${Y}${M}${D}";
		unless($lessons->{$date}){ $lessons->{$date} = []; }
		push(@{$lessons->{$date}}, $r);
	}
	#先月の末日の日付情報
	my $last_month = $osch->get_last_month_last_day_info($dt->{Y}, $dt->{n});
	my $last_month_ym = $last_month->{Y} . $last_month->{m};
	my $last_month_disabled = "";
	if( $last_month_ym lt $ym_s || $last_month_ym gt $ym_e ) {
		$last_month_disabled = "disabled";
	}
	#来月の1日の日付情報
	my $next_month = $osch->get_next_month_first_day_info($dt->{Y}, $dt->{n});
	my $next_month_ym = $next_month->{Y} . $next_month->{m};
	my $next_month_disabled = "";
	if( $next_month_ym lt $ym_s || $next_month_ym gt $ym_e ) {
		$next_month_disabled = "disabled";
	}
	#今月のある日の情報（第二週目の日曜日）
	my $this_month = $this_month_date_list->[1]->[0];
	#会員のポイント有効期限を過ぎた日付けを無効にする
#	for my $w (@{$this_month_date_list}) {
#		for my $d (@{$w}) {
#			if("$d->{Y}-$d->{m}-$d->{d}" gt $self->{session}->{data}->{member}->{member_point_expire} ) {
#				$d->{disabled} = "disabled";
#			}
#		}
#	}
	#
	$context->{this_month_date_list} = $this_month_date_list;
	$context->{last_month} = $last_month;
	$context->{next_month} = $next_month;
	$context->{this_month} = $this_month;
	$context->{last_month_disabled} = $last_month_disabled;
	$context->{next_month_disabled} = $next_month_disabled;
	$context->{ym} = $ym;
	$context->{lessons} = $lessons;
	$context->{proc} = $proc;
	return $context;
}

1;
