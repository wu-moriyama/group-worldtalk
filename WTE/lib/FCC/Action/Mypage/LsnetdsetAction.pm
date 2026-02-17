package FCC::Action::Mypage::LsnetdsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Schedule;
use FCC::Class::Lesson;
use FCC::Class::Member;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Tmpl;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
	$self->del_proc_session_data();
	my $proc = $self->create_proc_session_data("lsnrsv");
	$proc->{in} = {};
	#スケジュール識別IDを取得
	my $lsn_id = $self->{q}->param("lsn_id");
	if( ! defined $lsn_id || $lsn_id eq "" || $lsn_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#レッスンが延長可能かどうかをチェック
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $res = $olsn->is_extendable($lsn_id);
	unless($res->{extendable}) {
		$context->{fatalerrs} = [$res->{message}];
		return $context;
	}
	my $lsn = $res->{lsn};
	my $sch = $res->{sch};
	my $member = $res->{member};
	#会員識別IDのチェック
	if($member_id != $member->{member_id}) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#スケジュール情報を登録
	unless($sch) {
		my $sY = $lsn->{lsn_etime_Y};
		my $sM = $lsn->{lsn_etime_m};
		my $sD = $lsn->{lsn_etime_d};
		my $sh = $lsn->{lsn_etime_H};
		my $sm = $lsn->{lsn_etime_i};
		my $stime = $sY . $sM . $sD . $sh . $sm;
		my $osch = new FCC::Class::Schedule(conf=>$self->{conf}, db=>$self->{db});
		my $sch_rec = {
			prof_id   => $lsn->{prof_id},
			lsn_id    => 0,
			sch_stime => $self->get_sch_stime($stime),
			sch_etime => $self->get_sch_etime($stime, $lsn->{prof_step})
		};
		$osch->add([$sch_rec]);
		$sch = $osch->get_from_stime($lsn->{prof_id}, $stime);
	}
	#予約処理（すでに報告完了状態にする）
	my $now = time;
	my $new_lsn = $olsn->add({
		sch_id       => $sch->{sch_id},
		prof_id      => $sch->{prof_id},
		member_id    => $member_id,
		seller_id    => $member->{seller_id},
		lsn_stime    => $sch->{sch_stime},
		lsn_etime    => $sch->{sch_etime},
		lsn_prof_fee => $lsn->{prof_fee},
		lsn_pay_type => $lsn->{lsn_pay_type},
		coupon_id    => ($member->{coupon_id} && $lsn->{lsn_pay_type} == 2) ? $member->{coupon_id} : 0,
		lsn_prof_repo        => 1,
		lsn_prof_repo_date   => $now,
		lsn_member_repo      => 1,
		lsn_member_repo_date => $now
	});
	#通知メール送信
	my $ml_data = {};
	while( my($k, $v) = each %{$sch} ) {
		$ml_data->{$k} = $v;
	}
	while( my($k, $v) = each %{$new_lsn} ) {
		$ml_data->{$k} = $v;
	}
	while( my($k, $v) = each %{$self->{session}->{data}->{member}} ) {
		$ml_data->{$k} = $v;
	}
	$self->send_mail($ml_data);
	#
	$proc->{in} = $ml_data;
	$self->set_proc_session_data($proc);
	#
	$context->{proc} = $proc;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	unless($in->{member_email}) { return; }
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	for my $tmpl_id ("rsv9001", "rsv9002") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
		}
		$t->param("ssl_host_url" => $self->{conf}->{ssl_host_url});
		$t->param("sys_host_url" => $self->{conf}->{sys_host_url});
		$t->param("pub_sender" => $self->{conf}->{pub_sender});
		$t->param("pub_from" => $self->{conf}->{pub_from});
		#ヘッダーとボディー
		my $eml = $t->output();
		my $mail = new FCC::Class::Mail::Sendmail(
			sendmail => $self->{conf}->{sendmail_path},
			smtp_host => $self->{conf}->{smtp_host},
			smtp_port => $self->{conf}->{smtp_port},
			smtp_auth_user => $self->{conf}->{smtp_auth_user},
			smtp_auth_pass => $self->{conf}->{smtp_auth_pass},
			smtp_timeout => $self->{conf}->{smtp_timeout},
			eml => $eml,
			tz => $self->{conf}->{tz}
		);
		$mail->mailsend();
	 	if( my $error = $mail->error() ) {
	 		die $error;
	 	}
	}
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
