package FCC::Action::Admin::SchaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use Date::Pcalc;
use FCC::Class::Date::Utils;
use FCC::Class::Prof;
use FCC::Class::Schedule;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "schadd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'd',
		'tm',
		'prof_id'
	];
	# FCC:Class::Scheduleインスタンス
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
	#入力値を取得
	my $in = $self->get_input_data($in_names, ['tm']);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($in->{prof_id});
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
				prof_id   => $in->{prof_id},
				lsn_id    => 0,
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
