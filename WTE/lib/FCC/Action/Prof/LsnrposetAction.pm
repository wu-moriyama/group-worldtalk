package FCC::Action::Prof::LsnrposetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
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
	if($lsn->{prof_id} != $prof_id) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($lsn->{lsn_cancel} > 0) {
		$context->{fatalerrs} = ["すでにキャンセル済みです。"];
		return $context;
	}
	unless($lsn->{lsn_report_available}) {
		$context->{fatalerrs} = ["完了報告の期限が切れています。"];
		return $context;
	}
	if($lsn->{lsn_prof_repo} > 0) {
		$context->{fatalerrs} = ["すでに報告済みです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'lsn_prof_repo',
		'lsn_prof_repo_note'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my @errs = $olsn->prof_repo_input_check($in_names, $in);
	#エラーハンドリング
	if(@errs) {
		$context->{fatalerrs} = [$errs[0]->[1]];
		return $context;
	}
	$proc->{errs} = [];
	#報告処理
	$in->{lsn_id} = $lsn_id;
	$lsn = $olsn->prof_repo_set($in, $lsn);
	#通知メール送信
	my $p = $lsn->{lsn_prof_repo};
	my $m = $lsn->{lsn_member_repo};
	if( $p > 0 && $m > 0 && ( ($p == 1 && $m >= 2) || $p >= 2 ) ) {
		my $ml_data = {};
		while( my($k, $v) = each %{$lsn} ) {
			$ml_data->{$k} = $v;
			if($k =~ /^lsn_(prof_repo|member_repo|status)$/) {
				$ml_data->{"${k}_${v}"} = 1;
			}
		}
		my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($lsn->{member_id});
		while( my($k, $v) = each %{$member} ) {
			$ml_data->{$k} = $v;
		}
		$self->send_mail($ml_data);
	}
	#
	$self->del_proc_session_data();
	$context->{lsn_id} = $lsn_id;
	return $context;
}

sub send_mail {
	my($self, $in) = @_;
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	for my $tmpl_id ("rep9001") {
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
