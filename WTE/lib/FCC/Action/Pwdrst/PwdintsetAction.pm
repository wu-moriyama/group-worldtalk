package FCC::Action::Pwdrst::PwdintsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Pwdrst::_SuperAction);
use FCC::Class::Member;
use FCC::Class::String::Checker;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Tmpl;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "pwdrst");
	if( ! $proc || ! $proc->{member_id} ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'member_pass',
		'member_pass2'
	];
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	$proc->{in}->{member_id} = $proc->{member_id};
	#会員情報を取得
	my $member = $omember->get($proc->{member_id});
	if( ! $member || $member->{member_status} != 1 ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値チェック
	my @errs = $omember->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		#パスワード更新
		$omember->mod({
			member_id => $member->{member_id},
			member_pass => $proc->{in}->{member_pass}
		});
		#メール送信
		my $in = {};
		while( my($k, $v) = each %{$member} ) {
			$in->{$k} = $v;
		}
		$self->send_mail($in);
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
	my $t = $ot->get_template_object("pwd9002");
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

1;
