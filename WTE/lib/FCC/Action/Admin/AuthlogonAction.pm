package FCC::Action::Admin::AuthlogonAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Passwd;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	#入力されたID/パスワードを取得
	my $in_names = ['id', 'pass', 'auto_logon_enable'];
	my $in = $self->get_input_data($in_names);
	#入力値をチェック
	my @errs;
	my $pw = new FCC::Class::Passwd(conf=>$self->{conf});
	unless($pw) { die $!; }
	if( ! ($in->{id} && $in->{pass}) ) {
		push(@errs, '管理者ID、パスワードを入力してください。');
	} else {
		#パスワードチェック
		if( my $auth_res = $pw->auth( { id=>$in->{id}, pass=>$in->{pass} } ) ) {
			my $msg = "認証に失敗しました。";
			if($auth_res == 5) {
				$msg = "パスワードロックのためご利用いただけません。";
				#通知メール送信
				$self->passwd_lock_notice($in);
			}
			push(@errs, $msg);
		}
	}
	#コンテキストにパラメータをセット
	my $context = {};
	$context->{in} = $in;
	if(@errs) {
		$pw->fail_increment($in->{id});
		$context->{errs} = \@errs;
	} else {
		my $sid = $self->{session}->create({id=>$in->{id}});
		unless($sid) {
			my $err = "セッションの生成に失敗しました。(2) : " . $self->{session}->error();
			die $err;
		}
		$pw->mod($in->{id}, {last=>time});
		$context->{sid} = $sid;
		$context->{auto_logon_enable} = 0;
		if($self->{conf}->{auto_logon} && $in->{auto_logon_enable} eq "1") {
			$context->{auto_logon_enable} = 1;
		}
	}
	return $context;
}

sub passwd_lock_notice {
	my($self, $in) = @_;
	#通知先アドレスがセットされていなければ終了
	unless($self->{conf}->{notice_to}) { return; }
	#テンプレートを読み取る
	my $t = $self->load_template("$self->{conf}->{TEMPLATE_DIR}/pass_lock_mail.txt");
	while( my($k, $v) = each %ENV ) {
		$t->param($k => $v);
	}
	while( my($k, $v) = each %{$in} ) {
		$t->param($k => $v);
	}
	$t->param("product_name" => $self->{conf}->{product_name});
	$t->param("notice_from" => $self->{conf}->{notice_from});
	$t->param("notice_to" => $self->{conf}->{notice_to});
	my $now = time;
	my @tm = FCC::Class::Date::Utils->new(time => $now, tz => $self->{conf}->{tz})->get(1);
	for( my $i=0; $i<=9; $i++ ) {
		$t->param("tm_${i}" => $tm[$i]);
	}
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
