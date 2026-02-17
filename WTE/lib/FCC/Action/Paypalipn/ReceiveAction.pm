package FCC::Action::Paypalipn::ReceiveAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Paypalipn::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Mbract;
use FCC::Class::Plan;
use FCC::Class::Card;
use FCC::Class::Auto;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Tmpl;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;
use HTTP::Request::Common;
use LWP::UserAgent;
use Unicode::Japanese;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#パラメータ取得
	my @names = $self->{q}->param();
	my $vars = ["cmd" => "_notify-validate"];
	my $msgs = {};
	for my $name ( @names ) {
		my $value = $self->{q}->param($name);
		push(@{$vars}, $name, $value);
		$msgs->{$name} = $value;
	}
	#取得したデータをチェック
	my($crd_id, $member_id, $pln_id) = split(/\-/, $msgs->{custom});
	if( ! $crd_id || $crd_id !~ /^\d+$/ ) {
		return $context;
	}
	if( ! $member_id || $member_id !~ /^\d+$/ ) {
		return $context;
	}
	#会員情報を取得
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db});
	my $member = $omember->get_from_db($member_id);
	unless($member) {
		return $context;
	}
	#カード決済情報を取得
	my $ocrd = new FCC::Class::Card(conf=>$self->{conf}, db=>$self->{db});
	my $crd = $ocrd->get($crd_id);
	unless($crd) {
		return $context;
	}
	#パラメーターチェック
	if($member_id != $crd->{member_id}) {
		return $context;
	}
	if($msgs->{mc_gross} != $crd->{crd_price}) {
		return $context;
	}
	#プラン情報を取得
	my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
	my $pln = $opln->get($pln_id);
	#確認リクエスト送信
$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;
	my $ua = LWP::UserAgent->new();
$ua->ssl_opts( verify_hostname => 0 );
	my $paypal_ipn_url = $self->{conf}->{paypal_ipn_url};
	my $res = $ua->post($paypal_ipn_url, $vars);
	my $res_content = $res->content();

	#パラメータを再読み込み
	my @names2 = $self->{q}->param();
	my $crd_ipn_message = "";
	for my $name ( @names2 ) {
		my $value = $self->{q}->param($name);
		$msgs->{$name} = $value;
		$crd_ipn_message .= "${name}: ${value}\n";
	}
	$crd_ipn_message .= "HTTP_RESPONSE_CODE: " . $res->code . " " . $res->message . "\n";
	$crd_ipn_message .= "CONFIRM_RESULT: " . $res_content . "\n";

	#確認リクエストの結果
	my $crd_success = 0;
	if ( $res->is_error() ) {
		$crd_success = 3;
	} elsif( $res_content =~ /^VERIFIED/) {
		$crd_success = 1;
	} elsif( $res_content =~ /^INVALID/) {
		$crd_success = 2;
	} else {
		$crd_success = 3;
	}
	#
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
			auto_txn_id      => $msgs->{txn_id}
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
	#カード決済情報をアップデート
	my $new_card = $ocrd->mod({
		crd_id => $crd_id,
		mbract_id => $mbract ? $mbract->{mbract_id} : 0,
		auto_id => $auto ? $auto->{auto_id} : 0,
		crd_rdate => $now,
		crd_success => $crd_success,
		crd_txn_id => $msgs->{txn_id},
		crd_payer_id => $msgs->{payer_id},
		crd_receipt_id => $msgs->{receipt_id},
		crd_ipn_message => Unicode::Japanese->new($crd_ipn_message, 'sjis')->get()
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
