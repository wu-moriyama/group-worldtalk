package FCC::Action::Admin::CrdscssetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Mbract;
use FCC::Class::Plan;
use FCC::Class::Card;
use FCC::Class::Auto;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Tmpl;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "crddtl");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}

	#該当のカード決済情報を取得
	my $crd_id = $proc->{in}->{crd_id};
	my $ocrd = new FCC::Class::Card(conf=>$self->{conf}, db=>$self->{db});
	my $crd = $ocrd->get($crd_id);
	unless($crd && $crd->{crd_success} == 3) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	my $member_id = $crd->{member_id};

	#会員情報を取得
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db});
	my $member = $omember->get_from_db($member_id);
	unless($member) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}

	#入力値を取得
	my $ocrd = new FCC::Class::Card(conf=>$self->{conf}, db=>$self->{db});
	my $crd_success = $self->{q}->param("crd_success");
	unless($crd_success == 1 || $crd_success == 2) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}

	#プラン情報を取得
	my $pln_id = $crd->{pln_id};
	my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
	my $pln = $opln->get($pln_id);

	my $now = time;
	my @tm = FCC::Class::Date::Utils->new(time=>$now, tz=>$self->{conf}->{tz})->get(1);

	#autosテーブル操作
	my $auto;
	if($crd_success == 1 && $crd->{crd_subscription} == 1) {
		my $oauto = new FCC::Class::Auto(conf=>$self->{conf}, db=>$self->{db});
		$oauto->stop_subscription({ member_id => $member_id, auto_stop_reason => 4 });
		$auto = $oauto->add({
			member_id        => $member_id,
			crd_id           => $crd_id,
			pln_id           => $pln_id,
			auto_price       => $crd->{crd_price},
			auto_point       => $crd->{crd_point},
			auto_day         => $tm[2] + 0,
			auto_last_ym     => $tm[0] . $tm[1],
			auto_status      => 1,
			auto_count       => 1,
			auto_mdate       => $now,
			auto_txn_id      => ""
		});
	}
	#ポイントチャージ
	my $mbract;
	if($crd_success == 1) {
		my $ombract = new FCC::Class::Mbract(conf=>$self->{conf}, db=>$self->{db});
		$mbract = $ombract->charge({
			member_id => $member_id,
			seller_id => $member->{seller_id},
			mbract_type => 1,
			mbract_reason => $crd->{crd_subscription} ? 42 : 41,
			mbract_price => $crd->{crd_point},
			crd_id => $crd_id,
			auto_id => $auto ? $auto->{auto_id} : 0,
		});
	}

	#カード決済情報を更新
	my $new_card = $ocrd->mod({
		crd_id => $crd_id,
		mbract_id => $mbract ? $mbract->{mbract_id} : 0,
		auto_id => $auto ? $auto->{auto_id} : 0,
		crd_rdate => $now,
		crd_success => $crd_success,
		crd_txn_id => "",
		crd_payer_id => "",
		crd_receipt_id => "",
		crd_ipn_message => ""
	});

	#通知メール送信
	my $mail_params = {};
	while( my($k, $v) = each %{$member} ) {
		$mail_params->{$k} = $v;
	}
	while( my($k, $v) = each %{$new_card} ) {
		$mail_params->{$k} = $v;
	}
	if($auto) {
		while( my($k, $v) = each %{$auto} ) {
			$mail_params->{$k} = $v;
		}
	}
	if($pln) {
		while( my($k, $v) = each %{$pln} ) {
			$mail_params->{$k} = $v;
		}
	}
	$self->send_mail($mail_params);

	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	#通知先アドレスがセットされていなければ終了
	unless($in->{member_email}) { return; }
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#現在日時
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	#
	for my $tmpl_id ("ppl9001") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k eq "crd_success") {
				$t->param("${k}_${v}" => 1);
			} elsif($k =~ /_(point|price)$/) {
				$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
			}
		}
		$t->param("ssl_host_url" => $self->{conf}->{ssl_host_url});
		$t->param("sys_host_url" => $self->{conf}->{sys_host_url});
		$t->param("pub_sender" => $self->{conf}->{pub_sender});
		$t->param("pub_from" => $self->{conf}->{pub_from});
		#現在日時
		for( my $i=0; $i<=9; $i++ ) {
			$t->param("tm_${i}" => $tm[$i]);
		}
		#ヘッダーとボディー
		my $eml = $t->output();
		unless($eml) { next; }
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
#	 		die $error;
	 	}
	}
}

1;
