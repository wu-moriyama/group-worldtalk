package FCC::Action::Reg::CptsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Reg::_SuperAction);
use Data::Random::String;
use CGI::Utils;
use FCC::Class::Member;
use FCC::Class::Coupon;
use FCC::Class::String::Checker;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Date::Utils;
use FCC::Class::Tmpl;
use FCC::Class::String::Conv;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "reg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値のname属性値のリスト
	my $in_names = [
		'member_lastname',
		'member_firstname',
		'member_handle',
		'member_email',
		'member_pass',
		'member_pass2'
	];
	#入力値チェック
	my @errs = $omember->input_check($in_names, $proc->{in});
	my $coupon_code = $proc->{in}->{coupon_code};
	my $coupon;
	if($coupon_code ne "") {
		if($coupon_code !~ /^[a-zA-Z0-9]{8}$/) {
			push(@errs, ["coupon_code", "ご指定のクーポンはご利用になれません。"]);
		} else {
			my $ocoupon = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
			$coupon = $ocoupon->get_from_db_by_code($coupon_code);
			if( ! $coupon || ! $coupon->{coupon_available} ) {
				push(@errs, ["coupon_code", "ご指定のクーポンはすでにご利用頂くことができなくなりました。"]);
			} else {
				$proc->{in}->{coupon_price} = $coupon->{coupon_price};
			}
		}
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $in = $proc->{in};
		$in->{seller_id} = $self->{session}->{data}->{seller}->{seller_id};
		if($coupon) {
			$in->{coupon_id} = $coupon->{coupon_id};
			$in->{seller_id} = $coupon->{seller_id};
		} else {
			$in->{coupon_id} = 0;
			$in->{seller_id} = $self->{session}->{data}->{seller}->{seller_id};
		}
		$in->{member_coupon} = 0;
		$in->{member_status} = 2;	#状態（2:仮登録）
		$in->{member_point} = 0;	#ポイント
		$in->{member_card} = 0;	#カード未登録
		$in->{member_passphrase} = Data::Random::String->create_random_string(length=>'8', contains=>'alphanumeric');
		my $member = $omember->add($in);
		$proc->{member} = $member;
		#本登録案内メール送信
		my $data = {};
		while( my($k, $v) = each %{$member} ) {
			$data->{$k} = $v;
		}
		my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($in->{seller_id});
		while( my($k, $v) = each %{$seller} ) {
			$data->{$k} = $v;
		}
		$data->{coupon_price} = $proc->{in}->{coupon_price};
		$self->send_mail($data);
	}
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
	my $t = $ot->get_template_object("reg9001");
	#置換
	while( my($k, $v) = each %{$in} ) {
		$t->param($k => $v);
		if($k eq "coupon_price") {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	$t->param("ssl_host_url" => $self->{conf}->{ssl_host_url});
	$t->param("sys_host_url" => $self->{conf}->{sys_host_url});
	$t->param("pub_sender" => $self->{conf}->{pub_sender});
	$t->param("pub_from" => $self->{conf}->{pub_from});
	#本登録有効日
	my $expire_epoch = time + $self->{conf}->{reg_interim_expire}*86400;
	my @etm = FCC::Class::Date::Utils->new(time=>$expire_epoch, tz=>$self->{conf}->{tz})->get(1);
	for( my $i=0; $i<=5; $i++ ) {
		$t->param("reg_interim_expire_${i}" => $etm[$i]);
	}
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
