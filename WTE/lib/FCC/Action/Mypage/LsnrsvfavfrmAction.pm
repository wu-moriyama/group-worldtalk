package FCC::Action::Mypage::LsnrsvfavfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use Date::Pcalc;
use FCC::Class::Schedule;
use FCC::Class::Date::Utils;
use FCC::Class::Prof;
use FCC::Class::Fav;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
	#指定年月を取得
	my $ymd = $self->{q}->param("d");
	if( $ymd =~ /^(\d{4})(\d{2})(\d{2})$/ ) {
		my $y = $1;
		my $m = $2;
		my $d = $3;
		if( Date::Pcalc::check_date($y, $m, $d) ) {
			if( ! $osch->is_available_date($ymd) ) {
				$context->{fatalerrs} = ["不正なリクエストです。(1)"];
				return $context;
#			} elsif("${y}-${m}-${d}" gt $self->{session}->{data}->{member}->{member_point_expire} ) {
#				$context->{fatalerrs} = ["ポイントの有効期限を過ぎた日付で予約することはできません。"];
#				return $context;
			}
		} else {
			$context->{fatalerrs} = ["不正なリクエストです。(3)"];
			return $context;
		}
	} else {
		$context->{fatalerrs} = ["不正なリクエストです。(4)"];
		return $context;
	}
	#講師フィルタ
	my $fav_params = {
		member_id   => $member_id,
		prof_status => 1
	};
	my $ofav = new FCC::Class::Fav(conf=>$self->{conf}, db=>$self->{db});
	my $prof_id_list = $ofav->get_prof_id_list($fav_params);

	#登録済みのスケジュールを取得
	my $params = {
		prof_id_list => $prof_id_list,
		sch_date_s => $ymd,
		sch_date_e => $ymd,
		offset => 0,
		limit => 9999,
		sort => [['sch_stime', 'ASC']]
	};
	my $res = $osch->get_list($params);
	my $sch_list = [];
	for my $r (@{$res->{list}}) {
		if($r->{prof_status} != 1) { next; }
		if( $r->{disabled} ) { next; }
		if( $r->{lsn_id} ) { next; } #予約済みの枠は非表示にしたいとのこと
		push(@{$sch_list}, $r);
	}
	#前後一週間分の日付情報
	my $week = [];
	my $member_point_expire = $self->{session}->{data}->{member}->{member_point_expire};
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
			} elsif($member_point_expire && "${Y}-${M}-${D}" gt $member_point_expire ) {
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
