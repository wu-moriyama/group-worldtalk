package FCC::Action::Site::IndexAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Site::_SuperAction);
use Date::Pcalc;
use FCC::Class::Schedule;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});

	#指定年月を取得
	my $ymd = $self->{q}->param("d");
	if( $ymd =~ /^(\d{4})(\d{2})(\d{2})$/ ) {
		my $y = $1;
		my $m = $2;
		my $d = $3;
		if( Date::Pcalc::check_date($y, $m, $d) ) {
			#if( ! $osch->is_available_date($ymd) ) {
			#	$context->{fatalerrs} = ["不正なリクエストです。(1)"];
			#	return $context;
			#}
		} else {
			$context->{fatalerrs} = ["不正なリクエストです。(2)"];
			return $context;
		}
	} else {
		my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
		$ymd = $tm[0] . $tm[1] . $tm[2];
	}
	#登録済みのスケジュールを取得
	my $params = {
		sch_date_s => $ymd,
		sch_date_e => $ymd,
		offset => 0,
		limit => 9999,
		sort => [['sch_stime', 'ASC']]
	};
	my $res = $osch->get_list($params);
	my $sch_list = [];
	for my $r (@{$res->{list}}) {
		if( ! $r->{prof_status} ) { next; }
		if( $r->{disabled} ) { next; }
		if( $r->{lsn_id} ) { next; } #予約済みの枠は非表示にしたいとのこと
		push(@{$sch_list}, $r);
	}
	#前後一週間分の日付情報
	my $week = [];
	if( $ymd =~ /^(\d{4})(\d{2})(\d{2})$/ ) {
		my $y = $1;
		my $m = $2;
		my $d = $3;
		my $hit_count = 0;
		for(my $delta=-3; $delta<=7; $delta++) {
			my($Y, $M, $D) = Date::Pcalc::Add_Delta_Days($y, $m, $d, $delta);
			$M = sprintf("%02d",$M);
			$D = sprintf("%02d",$D);
			my $YMD = $Y . $M . $D;
			if( ! $osch->is_available_date($YMD) ) {
				next;
			}
			push(@{$week}, $YMD);
			$hit_count ++;
			if($hit_count >= 7) {
				last;
			}
		}
	}
	#
	$context->{ymd} = $ymd;
	$context->{sch_list} = $sch_list;
	$context->{week} = $week;
	return $context;
}

1;
