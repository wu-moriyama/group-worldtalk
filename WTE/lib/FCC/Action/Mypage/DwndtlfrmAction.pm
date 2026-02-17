package FCC::Action::Mypage::DwndtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Dwn;
use FCC::Class::Dwnsel;
use FCC::Class::Member;
use FCC::Class::Lesson;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#識別IDを取得
	my $dwn_id = $self->{q}->param("dwn_id");
	if( ! defined $dwn_id || $dwn_id eq "" || $dwn_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#プロセスセッション
	$self->del_proc_session_data();
	my $proc = $self->create_proc_session_data("dwndtl");
	$proc->{in} = {};
	#情報を取得
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $dwn = $odwn->get($dwn_id);
	if( ! $dwn || $dwn->{dwn_status} != 1 ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#購入履歴
	my $odsl = new FCC::Class::Dwnsel(conf=>$self->{conf}, db=>$self->{db});
	my $dsl = $odsl->get_latest_from_dwn_member_id($dwn_id, $member_id);
	if($dsl) {
		while( my($k, $v) = each %{$dsl} ) {
			$dwn->{$k} = $v;
		}
	}
	#
	while( my($k, $v) = each %{$dwn} ) {
		$proc->{in}->{$k} = $v;
	}
	#ポイントの残高を確かめる
	my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($member_id);
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	$proc->{in}->{member_can_buy} = 0;
	$proc->{in}->{member_can_buy_by_point} = 0;
	$proc->{in}->{member_can_buy_by_coupon} = 0;
	$proc->{in}->{member_point} = $member->{member_point}; # 保持ポイント
	$proc->{in}->{member_receivable_point} = $olsn->get_receivable($member_id, 1); # ポイントの売り掛け
	$proc->{in}->{member_available_point} = $member->{member_point} - $proc->{in}->{member_receivable_point}; # 実質的に利用可能なポイント
	if( $proc->{in}->{member_available_point} >= $dwn->{dwn_point} ) {
		$proc->{in}->{member_can_buy} = 1;
		$proc->{in}->{member_can_buy_by_point} = 1;
	}
	#
	$self->set_proc_session_data($proc);
	#
	$context->{proc} = $proc;
	return $context;
}


1;
