package FCC::Action::Mypage::DwnbuysetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Member;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Date::Utils;
use FCC::Class::Tmpl;
use FCC::Class::Dwn;
use FCC::Class::Dwnsel;
use FCC::Class::Lesson;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwndtl");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#情報を取得
	my $in = $proc->{in};
	my $dwn_id = $in->{dwn_id};
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db});
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
	if( $dwn->{dsl_qualified} ) {
		$context->{fatalerrs} = ["この商品はすでに購入済みで、現在、ご利用頂ける状態のため、追加で購入することはできません。"];
		return $context;
	}
	#ポイントの残高を確かめる
	my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($member_id);
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $receivable_point = $olsn->get_receivable($member_id, 1); # ポイントの売り掛け
	my $available_point = $member->{member_point} - $receivable_point; # 実質的に利用可能なポイント
	if( $available_point < $dwn->{dwn_point} ) {
		$context->{fatalerrs} = ["ポイント残高が不足しています。"];
		return $context;
	}
	#購入処理
	my $dsl = $odsl->add({
		dwn_id       => $in->{dwn_id},
		member_id    => $member_id,
		seller_id    => $member->{seller_id},
		dsl_expire   => time + ($in->{dwn_period} * 3600),
		dsl_point    => $in->{dwn_point},
		dsl_type     => $in->{dwn_type}
	});
	while( my($k, $v) = each %{$dsl} ) {
		$proc->{in}->{$k} = $v;
	}
	#通知メール送信
	my $ml_data = {};
	while( my($k, $v) = each %{$proc->{in}} ) {
		$ml_data->{$k} = $v;
	}
	while( my($k, $v) = each %{$self->{session}->{data}->{member}} ) {
		$ml_data->{$k} = $v;
	}
	$self->send_mail($ml_data);
	#
	$context->{proc} = $proc;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	unless($in->{member_email}) { return; }
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	for my $tmpl_id ("dwn9001", "dwn9002") {
		my $t = $ot->get_template_object($tmpl_id);
		unless($t) { next; }
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k =~ /^(dwn_pubdate|dsl_expire)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$t->param("${k}_${i}" => $tm[$i]);
				}
			} elsif($k =~ /^dwn_(type|loc|status)$/) {
				$t->param("${k}_${v}" => 1);
			} elsif($k =~ /_(fee|coupon|point)$/) {
				$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
			}
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

1;
