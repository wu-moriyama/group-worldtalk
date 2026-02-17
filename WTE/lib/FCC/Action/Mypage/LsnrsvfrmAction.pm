package FCC::Action::Mypage::LsnrsvfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use Date::Pcalc;
use FCC::Class::Schedule;
use FCC::Class::Date::Utils;
use FCC::Class::Prof;

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
	my $prof_in_names = [
		's_prof_handle',
		's_prof_fee',
		's_prof_rank',
		's_prof_fulltext',
		's_prof_gender',
		's_prof_country',
		's_prof_residence',
		's_prof_reco',
		's_prof_character',
		's_prof_interest'
	];
	my $prof_params_in = $self->get_input_data($prof_in_names, ["s_prof_character", "s_prof_interest"]);
	my $prof_params = {};
	while( my($k, $v) = each %{$prof_params_in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		$prof_params->{$k} = $v;
	}
	$prof_params->{prof_status} = 1;
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $prof_id_list = $oprof->get_id_list($prof_params);

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

	#国選択肢リスト
	my $country_list = $oprof->get_prof_country_list();
	my $country_hash = $oprof->get_prof_country_hash();
	#
	$context->{ymd} = $ymd;
	$context->{sch_list} = $sch_list;
	$context->{week} = $week;
	$context->{country_list} = $country_list;
	$context->{country_hash} = $country_hash;
	$context->{prof_params} = $prof_params;
	return $context;
}

1;
