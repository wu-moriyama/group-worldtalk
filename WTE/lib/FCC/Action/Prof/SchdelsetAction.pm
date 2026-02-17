package FCC::Action::Prof::SchdelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use Date::Pcalc;
use FCC::Class::Date::Utils;
use FCC::Class::Prof;
use FCC::Class::Schedule;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($prof_id);
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "schadd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。(1)"];
		return $context;
	}
	#
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
	#入力値のname属性値のリスト
	my $in_names = [
		'd',
		'sch_id'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}


	my $dbh = $self->{db}->connect_db();

	my $sql = "SELECT group_id FROM schedules where sch_id='$in->{sch_id}'";
	my $group_id = $dbh->selectrow_array($sql);

	#既に予約されているユーザーがいないか確認
	if($group_id) {

		my $sql = "SELECT sch_stime FROM schedules where sch_id='$in->{sch_id}'";
		my $sch_stime = $dbh->selectrow_array($sql);

		my $sql = "SELECT course_id FROM schedules where sch_id='$in->{sch_id}'";
		my $course_id = $dbh->selectrow_array($sql);

		my $sql = "SELECT count(lsn_id) FROM lessons where lsn_stime='$sch_stime' AND course_id = '$course_id' AND lsn_cancel=0";
		my $lsn_count = $dbh->selectrow_array($sql);

		if($lsn_count){

			$context->{fatalerrs} = ["既に予約されている為スケジュールを削除する事ができません"];
			return $context;

		}

	}
	
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in}, $osch, $prof_id);
	if(@errs) {
		$context->{fatalerrs} = ["不正なリクエストです。(2)"];
		return $context;
	}
	#削除処理
	$osch->del($in->{sch_id});
	$self->del_proc_session_data();
	#
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $names, $in, $osch, $prof_id) = @_;
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
					push(@errs, [$k, "不正なパラメータ(11)"]);
				} else {
					#my $week_date_list = $osch->get_week_date_list($Y, $M, $D);
					#my $last_day = $week_date_list->[6];
					#if( ! $last_day ) {
					#	push(@errs, [$k, "不正なパラメータ(12)"]);
					#} else {
					#	my $date = $last_day->{Y} . $last_day->{m} . $last_day->{d};
					#	if( ! $osch->is_available_date($date) ) {
					#		push(@errs, [$k, "不正なパラメータ(13)"]);
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
				push(@errs, [$k, "不正なパラメータ(14)"]);
			}
			if(@errs) {
				$in->{$k} = "";
			}
		#識別ID
		} elsif($k eq "sch_id") {
			if($v eq "" || $v =~ /[^\d]/) {
				push(@errs, [$k, "不正なパラメータ(21)"]);
			}
			my $sch = $osch->get($v);
			if( ! $sch ) {
				push(@errs, [$k, "不正なパラメータ(22)"]);
			} elsif($sch->{prof_id} ne $prof_id) {
				push(@errs, [$k, "不正なパラメータ(23)"]);
			} elsif($sch->{lsn_id}) {
				push(@errs, [$k, "不正なパラメータ(24)"]);
			} else {
				my($Y, $M, $D, $h, $m) = $sch->{sch_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
				if( ! $osch->is_available_datetime("${Y}${M}${D}${h}${m}") ) {
					push(@errs, [$k, "不正なパラメータ(25)"]);
				}
			}
		}
	}
	#
	return @errs;
}

1;
