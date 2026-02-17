package FCC::Action::Mypage::MbrdelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Tmpl;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrdel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#会員情報を取得
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	my $member = $omember->get_from_db($member_id);
	#削除処理
	$omember->del($member_id);
	$proc->{in} = $member;
	#通知メール送信
	my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($member->{seller_id});
	$self->send_mail($member);
	#
	$context->{proc} = $proc;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	#通知先アドレスがセットされていなければ終了
	unless($in->{member_email}) { return; }
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $t = $ot->get_template_object("mpg9001");
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
