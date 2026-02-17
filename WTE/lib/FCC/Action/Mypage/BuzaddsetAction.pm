package FCC::Action::Mypage::BuzaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Buzz;
use FCC::Class::Prof;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Tmpl;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "lsndtl");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#レッスン識別IDを取得
	my $lsn_id = $self->{q}->param("lsn_id");
	if( ! defined $lsn_id || $lsn_id eq "" || $lsn_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#レッスン情報を取得
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $lsn = $olsn->get($lsn_id);
	if( ! $lsn ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($lsn->{member_id} != $member_id) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($lsn->{prof_status} != 1) {
		$context->{fatalerrs} = ["現在、クチコミを受け付けることができません。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'buz_content'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my $obuz = new FCC::Class::Buzz(conf=>$self->{conf}, db=>$self->{db});
	my @errs = $obuz->input_check($in_names, $in);
	#エラーハンドリング
	if(@errs) {
		$context->{fatalerrs} = [$errs[0]->[1]];
		return $context;
	}
	$proc->{errs} = [];
	my $buz = $obuz->add({
		member_id     => $member_id,
		prof_id       => $lsn->{prof_id},
		buz_content   => $in->{buz_content}
	});
	#通知メール送信
	my $ml_data = {};
	while( my($k, $v) = each %{$buz} ) {
		$ml_data->{$k} = $v;
	}
	while( my($k, $v) = each %{$lsn} ) {
		$ml_data->{$k} = $v;
	}
	while( my($k, $v) = each %{$self->{session}->{data}->{member}} ) {
		$ml_data->{$k} = $v;
	}
	$self->send_mail($ml_data);
	#
	$self->del_proc_session_data();
	$context->{lsn_id} = $lsn->{lsn_id};
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	unless($in->{member_email}) { return; }
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	for my $tmpl_id ("buz9001", "buz9002") {
		my $t = $ot->get_template_object($tmpl_id);
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
}

1;
