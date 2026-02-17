package FCC::Action::Mypage::BnkcptsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Mail::Sendmail;
use FCC::Class::Tmpl;
use FCC::Class::String::Conv;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "bnk");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($proc->{in}->{confirm_ok} != 1) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	my $member = $proc->{member};
	my $in = {};
	while( my($k, $v) = each %{$proc->{in}} ) {
		$in->{$k} = $v;
	}
	while( my($k, $v) = each %{$member} ) {
		$in->{$k} = $v;
	}
	$self->send_mail($in);
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
	for my $tmpl_id ("pay9001", "pay9002") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k =~ /_(point|price)/) {
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
