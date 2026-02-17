package FCC::Action::Mypage::ParentAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Passwd;
use FCC::Class::Ann;
use FCC::Class::Dwn;
use FCC::Class::Lesson;
use FCC::Class::Member;
use FCC::Class::Prep;
use FCC::Class::Date::Utils;
use FCC::Class::Auto;
use FCC::Class::Coupon;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#お知らせを取得
	my $oann = new FCC::Class::Ann(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $ann_list = $oann->get_list_for_dashboard(2);
	#動画一覧を取得
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db});
	my $res1 = $odwn->get_list({
		dwn_type   => 1,
		dwn_status => 1,
		sort       => [ ['dwn_weight', 'DESC'], ['dwn_score', 'DESC'], ['dwn_id', 'DESC'] ],
		offset     => 0,
		limit      => 5
	});
	my $dwn_1_list = $res1->{list};
	#PDF一覧を取得
	my $res2 = $odwn->get_list({
		dwn_type   => 2,
		dwn_status => 1,
		sort       => [ ['dwn_weight', 'DESC'], ['dwn_score', 'DESC'], ['dwn_id', 'DESC'] ],
		offset     => 0,
		limit      => 5
	});
	my $dwn_2_list = $res2->{list};
	#現在レッスン中のレッスン情報
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $lsn = $olsn->get_during($member_id);
	if($lsn) {
		#レッスンが延長可能かどうかをチェック
		my $res = $olsn->is_extendable($lsn->{lsn_id});
		$lsn->{lsn_extendable} = $res->{extendable};
	} else {
		$lsn = { lsn_extendable => 0 };
	}
	#最新の会員情報
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $member = $omember->get_from_db($member_id);
	#進捗報告を取得
	my $opre = new FCC::Class::Prep(conf=>$self->{conf}, db=>$self->{db});
	my $prep_res = $opre->get_list({
		member_id => $member_id,
		prep_status => 1,
		offset => 0,
		limit => 20,
		sort   => [["prep_id", "DESC"]]
	});
	my $prep_list = $prep_res->{list};
	#レッスン予約一覧
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $res = $olsn->get_list({
		member_id   => $member_id,
		lsn_stime_s => $tm[0] . $tm[1] . $tm[2],
		offset      => 0,
		limit       => 100,
		sort        => [["lsn_stime", "DESC"]]
	});
	my $lesson_list = $res->{list};
	#月額課金会員かどうか
	my $oauto = new FCC::Class::Auto(conf=>$self->{conf}, db=>$self->{db});
	my $auto = $oauto->is_subscription_member($member_id);
	if($auto) {
		$auto->{is_subscription_member} = 1;
	} else {
		$auto = { is_subscription_member => 0 };
	}
	#クーポン情報を取得
	if($member->{coupon_id} && $member->{member_coupon}) {
		my $ocoupon = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
		my $coupon = $ocoupon->get($member->{coupon_id});
		$member->{member_coupon_expire} = $coupon->{coupon_expire};
	}
	#
	$context->{ann_list} = $ann_list;
	$context->{dwn_1_list} = $dwn_1_list;
	$context->{dwn_2_list} = $dwn_2_list;
	$context->{lsn} = $lsn;
	$context->{member} = $member;
	$context->{prep_list} = $prep_list;
	$context->{lesson_list} = $lesson_list;
	$context->{auto} = $auto;
	return $context;
}


1;
