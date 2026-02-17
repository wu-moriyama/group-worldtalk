package FCC::Action::Honreg::AthsmtAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Honreg::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Seller;
use FCC::Class::Mbract;
use FCC::Class::Cpnact;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Tmpl;
use FCC::Class::Coupon;
use FCC::Class::Log;
use FCC::Class::String::Conv;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#パラメータ取得
	my $member_id = $self->{q}->param("i");
	my $member_passphrase = $self->{q}->param("p");
	my $seller_id = $self->{q}->param("s");
	#
	my $err = 0;
	#パラメーターチェック
	if( ! $member_id || $member_id !~ /^\d+$/ || ! $member_passphrase || $member_passphrase !~ /^[a-zA-Z0-9]{8}$/ || ! $seller_id || $seller_id !~ /^\d+$/ ) {
		$context->{err} = 9;
		return $context;
	}
	#
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $member = $omember->get_from_db($member_id);
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $seller = $oseller->get($seller_id);
	$context->{seller} = $seller;
	#
	if( ! $member ) {
		$context->{err} = 9;
		return $context;
	}
	if($member->{member_status} != 2) {
		$context->{err} = 1;
		return $context;
	}
	if($member->{member_passphrase} ne $member_passphrase) {
		$context->{err} = 9;
		return $context;
	}
	if($member->{seller_id} ne $seller_id) {
		$context->{err} = 9;
		return $context;
	}
	#
	if( ! $seller ) {
		$context->{err} = 9;
		return $context;
	}
	if($seller->{seller_status} != 1) {
		$context->{err} = 9;
		return $context;
	}
	#二重リクエスト防止
	{
		my $dbh = $self->{db}->connect_db();
		my $sql = "UPDATE members SET member_status=1 WHERE member_id=${member_id} AND member_status=2";
		my $updated = 0;
		eval {
			$updated = $dbh->do($sql);
			$dbh->commit();
		};
		if($@) {
			$dbh->rollback();
			my $msg = "failed to update a member record in members table.";
			FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${sql}");
			croak $msg;
		}
		if($updated == 0) {
			$context->{err} = 9;
			return $context;
		}
	}
	#ステータスアップデート（実際のアップデート処理）
	my $now = time;
	my $u = {};
	$u->{member_id} = $member_id;
	$u->{member_status} = 1;
	$u->{member_mdate} = $now;
	my $mbr = $omember->mod($u);
	#ポイントチャージ
	if($self->{conf}->{hon_point_add} > 0) {
		my $p = {
			member_id => $member->{member_id},
			seller_id => $member->{seller_id},
			mbract_type => 1,
			mbract_reason => 11,
			mbract_price => $self->{conf}->{hon_point_add}
		};
		my $ombract = new FCC::Class::Mbract(conf=>$self->{conf}, db=>$self->{db});
		$ombract->charge($p);
	}
	#クーポンチャージ
	if($member->{coupon_id}) {
		my $coupon_id = $member->{coupon_id};
		my $ocoupon = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
		my $coupon = $ocoupon->get($coupon_id);
		if( $coupon && $coupon->{coupon_available} ) {
			my $p = {
				member_id => $member->{member_id},
				seller_id => $member->{seller_id},
				coupon_id => $coupon_id,
				cpnact_type => 1,
				cpnact_reason => 11,
				cpnact_price => $coupon->{coupon_price}
			};
			my $ocpnact = new FCC::Class::Cpnact(conf=>$self->{conf}, db=>$self->{db});
			$ocpnact->charge($p);
			#
			$ocoupon->incr_num($coupon_id);
			#
			$mbr->{member_coupon} = $coupon->{coupon_price};
		}
	}
	#通知メール送信
	$self->send_notice_mail($mbr, $seller);
	#
	$context->{member_id} = $member_id;
	$context->{lang} = $member->{member_lang};
	return $context;
}

sub send_notice_mail {
	my($self, $member, $seller) = @_;
	my $in = {};
	while( my($k, $v) = each %{$member} ) {
		$in->{$k} = $v;
	}
	while( my($k, $v) = each %{$seller} ) {
		$in->{$k} = $v;
	}
	#通知先アドレスがセットされていなければ終了
	unless($in->{member_email}) { return; }
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $t = $ot->get_template_object("reg9002");
	#置換
	while( my($k, $v) = each %{$in} ) {
		$t->param($k => $v);
		if($k eq "member_coupon") {
			my $with_comma = FCC::Class::String::Conv->new($v)->comma_format();
			$t->param("${k}_with_comma" => $with_comma);
			$t->param("coupon_price_with_comma" => $with_comma);
			$t->param("coupon_price" => $v);
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

1;
