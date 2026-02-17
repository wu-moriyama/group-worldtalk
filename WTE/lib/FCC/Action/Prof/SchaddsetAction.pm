package FCC::Action::Prof::SchaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use Date::Pcalc;
use FCC::Class::Date::Utils;
use FCC::Class::Prof;
use FCC::Class::Schedule;
use Data::Dumper;
use Time::Local;


sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($prof_id);
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "schadd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}

	my $dbh = $self->{db}->connect_db();



	#入力値のname属性値のリスト
	my $in_names = [
		'd',
		'tm',
		'group',
		'course_id',
		'g_date',
		'g_time_st',
		'g_time_en',
		'g_ct'
	];
	# FCC:Class::Scheduleインスタンス
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
	#入力値を取得
	my $in = $self->get_input_data($in_names, ['tm']);

	my $group_id = 0;

	my $lsn_id = 0;
	my $course_id = 0;

	$course_id = $in->{course_id};

	if($in->{group} == 1) {

		if( ! $course_id) {
			$context->{fatalerrs} = ["授業が選択されていません"];
			return $context;
		}

		#24時対策
		my $g_date24 = "";
		my $g_date_en24 = "";
		my $day24 = "";
		my $month24 = "";
		my $year24 = "";
		if($in->{g_time_en} == "24:00"){

			my $st_year24  = substr($in->{g_date}, 0, 4);
			my $st_month24 = substr($in->{g_date}, 5, 2);
			my $st_day24   = substr($in->{g_date}, 8, 2);

			my $st24 = timelocal(0, 0, 0, $st_day24, $st_month24 - 1, $st_year24 -1900);

			my $num24 = 60 * 60 * 24 * 1;

			( undef, undef, undef, $day24, $month24, $year24 ) = localtime($st24 + $num24);
			$year24 += 1900;
			$month24 += 1;

			$g_date24    = $year24."-".$month24."-".$day24;
			$g_date_en24 = "00:00";

		}

		my $now = time;
		my $group_st_hour = $in->{g_date}." ".$in->{g_time_st}.":00";
		my $group_en_hour = "";
		if($in->{g_time_en} == "24:00"){
			$group_en_hour = $g_date24." ".$g_date_en24.":00";
		}else{
			$group_en_hour = $in->{g_date}." ".$in->{g_time_en}.":00";
		}

		#枠が埋まっていないか確認
		my $sql = "SELECT count(*) FROM schedules where sch_stime >='$group_st_hour' AND sch_etime <='$group_en_hour' AND prof_id='$prof_id'";
		my $check_flag = $dbh->selectrow_array($sql);
		if($check_flag > 0){

			$context->{fatalerrs} = ["既に枠が埋まっています"];
			return $context;

		}

		my $sql = "INSERT INTO `group_schedules` (`prof_id`, `course_id`, `group_count`, `sch_cdate`, `sch_stime`, `sch_etime`) VALUES ('$prof_id','$course_id', '$in->{g_ct}', '$now', '$group_st_hour', '$group_en_hour');";
		$dbh->do($sql);
		$group_id = $dbh->{mysql_insertid};

		# 新テーブル group_lesson_slots にも登録（グループレッスン用DB）
		my $q_st = $dbh->quote($group_st_hour);
		my $q_en = $dbh->quote($group_en_hour);
		my $sql_slot = "INSERT INTO `group_lesson_slots` (`course_id`, `prof_id`, `slot_stime`, `slot_etime`, `capacity_max`, `capacity_current`, `status`, `cdate`, `mdate`) VALUES ($course_id, $prof_id, $q_st, $q_en, " . int($in->{g_ct}) . ", 0, 1, $now, 0)";
		$dbh->do($sql_slot);

		$dbh->commit();

		my $st_year  = substr($in->{g_date}, 0, 4);
		my $st_month = substr($in->{g_date}, 5, 2);
		my $st_day   = substr($in->{g_date}, 8, 2);
		my $st_hour  = substr($in->{g_time_st}, 0, 2);
		my $st_min   = substr($in->{g_time_st}, 3, 2);
		my $en_hour  = substr($in->{g_time_en}, 0, 2);
		my $en_min   = substr($in->{g_time_en}, 3, 2);


		my $en = "";
		my $st = timelocal(0, $st_min, $st_hour, $st_day, $st_month - 1, $st_year -1900);
		if($in->{g_time_en} == "24:00"){
			$en = timelocal(0, 0, 0, $day24, $month24 - 1, $year24 -1900);
		}else{
			$en = timelocal(0, $en_min, $en_hour, $st_day, $st_month - 1, $st_year -1900);
		}

		my $count;
		my $year;
		my $mon;
		my $mday;
		my $hour;
		my $min;
		my $sec = 0;
		my $ct = 0;
		for ($count = $st; $count < $en; $count = $count + 1800){



			($sec, $min, $hour, $mday, $mon, $year) = localtime($count);
			$year += 1900;
			$mon += 1;

			if( $hour < 10){
				$hour = "0".$hour;
			}
			if( $min == 0){
				$min = "00";
			}
			if( $mon < 10){
				$mon = "0".$mon;
			}

			if( $mday < 10){
				$mday = "0".$mday;
			}
			$in->{tm}->[$ct] = $year.$mon.$mday.$hour.$min;
			$ct++;
		}
	}


	#print Dumper $in;
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}

	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in}, $osch, $prof->{prof_step});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
		$self->set_proc_session_data($proc);
	} else {
		$proc->{errs} = [];
		my $list = [];

		for my $dt (@{$proc->{in}->{tm}}) {
			my $rec = {
				prof_id   => $prof_id,
				lsn_id    => $lsn_id,
				course_id    => $course_id,
				group_id  => $group_id,
				group_start_flag  => 0,
				group_count  => $in->{g_ct},
				sch_stime => $self->get_sch_stime($dt),
				sch_etime => $self->get_sch_etime($dt, $prof->{prof_step})
			};
			push(@{$list}, $rec);
		}
		$osch->add($list);
		$self->del_proc_session_data();
	}
	#
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $names, $in, $osch, $prof_step) = @_;
	#
	my $time_line_list = $osch->get_time_line($prof_step);
	my $valid_times = {};
	for my $ary (@{$time_line_list}) {
		my $h = sprintf("%02d", $ary->[0]);
		my $m = sprintf("%02d", $ary->[1]);
		$valid_times->{"${h}${m}"} = 1;
	}
	#
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		#週の初めの日付
		if($k eq "d") {
			if($v =~ /^(\d{4})(\d{2})(\d{2})$/) {
				my $Y = $1;
				my $M = $2;
				my $D = $3;
				if( ! Date::Pcalc::check_date($Y, $M, $D) ) {
					push(@errs, [$k, "不正なパラメータ(1)"]);
				} else {
					#my $week_date_list = $osch->get_week_date_list($Y, $M, $D);
					#my $last_day = $week_date_list->[6];
					#if( ! $last_day ) {
					#	push(@errs, [$k, "不正なパラメータ(2)"]);
					#} else {
					#	my $date = $last_day->{Y} . $last_day->{m} . $last_day->{d};
					#	if( ! $osch->is_available_date($date) ) {
					#		push(@errs, [$k, "不正なパラメータ(3)"]);
					#	}
					#}

					my $week_date_list = $osch->get_week_date_list($Y, $M, $D);
					my $available_day_num = 0;
					for(my $i=0; $i<@{$week_date_list}; $i++) {
						my $day = $week_date_list->[$i];
						my $date = $day->{Y} . $day->{m} . $day->{d};
						if($osch->is_available_date($date)) {
							$available_day_num ++;
						}
					}
					if($available_day_num == 0) {
						push(@errs, [$k, "不正なパラメータ(3)"]);
					}
				}
			} else {
				push(@errs, [$k, "不正なパラメータ(4)"]);
			}
			if(@errs) {
				$in->{$k} = "";
			}
		#登録日時リスト
		} elsif($k eq "tm") {
			if( ref($v) ne "ARRAY" ) {
				push(@errs, [$k, "不正なパラメータ(5)"]);
			} elsif(@{$v} == 0) {
				push(@errs, [$k, "一件もチェックされていません。"]);
			} else {
				for my $dt (@{$v}) {
					if($dt =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
						my $Y = $1;
						my $M = $2;
						my $D = $3;
						my $h = $4;
						my $m = $5;
						if( ! Date::Pcalc::check_date($Y, $M, $D) || $h < 0 || $h > 23 || $m < 0 || $m > 59) {
							push(@errs, [$k, "不正なパラメータ(6)"]);
						} elsif( ! $osch->is_available_datetime($dt) ) {
							push(@errs, [$k, "不正なパラメータ(7)"]);
						} elsif( ! $valid_times->{"${h}${m}"} ) {
							push(@errs, [$k, "不正なパラメータ(8)"]);
						}
					} else {
						push(@errs, [$k, "不正なパラメータ(9)"]);
					}
				}
			}
		}
	}
	#
	return @errs;
}

sub get_sch_stime {
	my($self, $dt) = @_;
	my($Y, $M, $D, $h, $m) = $dt =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
	my $formated = "${Y}-${M}-${D} ${h}:${m}:00";
	return $formated;
}

sub get_sch_etime {
	my($self, $dt, $prof_step) = @_;
	my($Y, $M, $D, $h, $m) = $dt =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
	my $formated = "${Y}-${M}-${D} ${h}:${m}:00";
	my $epoch = FCC::Class::Date::Utils->new(iso=>$formated, tz=>$self->{conf}->{tz})->epoch();
	$epoch += ($prof_step * 60);
	($Y, $M, $D, $h, $m) = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
	$formated = "${Y}-${M}-${D} ${h}:${m}:00";
	return $formated;
}

1;
