package FCC::Action::Prof::BilpdmsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Pdm;
use FCC::Class::Lesson;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Tmpl;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "bilpdm");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	my $in = $proc->{in};
	my $first_lsn_id = $in->{lsn_id_list}->[0];
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $first_lsn = $olsn->get($first_lsn_id);
	if( ! $first_lsn ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	} elsif( $first_lsn->{pdm_id} ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#請求申請をセット
	my $opdm = new FCC::Class::Pdm(conf=>$self->{conf}, db=>$self->{db});
	my $pdm = $opdm->add($prof_id, $proc->{in});
	#通知メール送信
	my $ml_data = {};
	while( my($k, $v) = each %{$pdm} ) {
		$ml_data->{$k} = $v;
	}
	while( my($k, $v) = each %{$self->{session}->{data}->{prof}} ) {
		$ml_data->{$k} = $v;
	}
	$self->send_mail($ml_data);
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	for my $tmpl_id ("pdm9001", "pdm9002") {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k eq "pdm_price") {
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
