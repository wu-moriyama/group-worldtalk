package FCC::Action::Pwdrst::CptsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Pwdrst::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Date::Utils;
use FCC::Class::String::Checker;
use FCC::Class::Tmpl;
use Data::Random::String;
use Crypt::CBC;
use MIME::Base64;
use CGI::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "pwdrst");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'member_email'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値のチェック
	my $email = $proc->{in}->{member_email};
	my $email_len = FCC::Class::String::Checker->new($email, "utf8")->get_char_num();
	my @errs;
	if($email eq "") {
		push(@errs, ["member_email", "メールアドレスは必須です。"]);
	} elsif($email_len > 255) {
		push(@errs, ["member_email", "メールアドレスは255文字以内で入力してください。"]);
	} elsif( ! FCC::Class::String::Checker->new($email)->is_mailaddress() ) {
		push(@errs, ["member_email", "メールアドレスとして不適切です。"]);
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		# メールアドレスから会員情報を取得
		my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		my $member = $omember->get_from_db_by_email($proc->{in}->{member_email});
		if($member && $member->{member_status} == 1) {
			my $in = {};
			while( my($k, $v) = each %{$member} ) {
				$in->{$k} = $v;
			}
			#有効期限
			my $expire_epoch = time + $self->{conf}->{pwdrst_session_expire};
			my @etm = FCC::Class::Date::Utils->new(time=>$expire_epoch, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=5; $i++ ) {
				$in->{"pwdrst_expire_${i}"} = $etm[$i];
			}
			#会員パスフレーズを更新
			my $member_passphrase = Data::Random::String->create_random_string(length=>'8', contains=>'alphanumeric');
			$omember->mod({
				member_id => $member->{member_id},
				member_passphrase => $member_passphrase
			});
			#トークン生成
			$in->{token} = $self->generate_token($member->{member_id}, $member_passphrase, $expire_epoch);
			#メール送信
			$self->send_mail($in);
		}
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub generate_token {
	my($self, $id, $passphrase, $expire) = @_;
	my $cipher = Crypt::CBC->new(
		-key    => $self->{conf}->{pwdrst_secret_key},
		-cipher => 'Rijndael_PP'
	);
	my $enc = $cipher->encrypt($id . "-" . $passphrase . "-" . $expire);
	my $token = MIME::Base64::encode_base64($enc);
	$token =~ s/\n//g;
	return CGI::Utils->new->urlEncode($token);
}

sub send_mail {
	my($self, $in) = @_;
	#通知先アドレスがセットされていなければ終了
	unless($in->{member_email}) { return; }
	#テンプレートを読み取る
	my $ot = new FCC::Class::Tmpl(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $t = $ot->get_template_object("pwd9001");
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
