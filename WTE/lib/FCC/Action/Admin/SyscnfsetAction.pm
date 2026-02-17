package FCC::Action::Admin::SyscnfsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use Net::Netmask;
use Mail::SendEasy;
use Time::ZoneInfo;
use Email::Valid;
use FCC::Class::Syscnf;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "syscnf");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = ['hosts_allow', 'pass_lock_limit', 'static_url', 'sendmail_path', 'smtp_host', 'smtp_port', 'smtp_auth_user', 'smtp_auth_pass', 'notice_to', 'notice_from', 'session_expire', 'auto_logon', 'tz'];
	#入力値を取得
	$proc->{in} = $self->get_input_data($in_names);
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		#システム設定情報をセット
		FCC::Class::Syscnf->new(conf=>$self->{conf}, memd=>$self->{memd}, db=>$self->{db})->set($proc->{in});
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $names, $in) = @_;
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		#許可するIPアドレス 
		if($k eq "hosts_allow") {
			my @lines = split(/\n+/, $v);
			my @blocks;
			my @valid_blocks;
			for my $block (@lines) {
				$block =~ s/\r//g;
				$block =~ s/\s//g;
				if($block eq "") { next; }
				if($block =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.(\d{1,3})$/) {
					if($1 == 0) {
						$block .= "/24";
					} else {
						$block .= "/32";
					}
				}
				my $nm = new2 Net::Netmask($block);
				if($nm) {
					my $base = $nm->base();
					if($block !~ /^\Q${base}\E\//) {
						my $correct = $block;
						$correct =~ s/^[^\/]+/${base}/;
						push(@errs, [$k, "\"許可するIPアドレス\"に指定したアドレスブロック '${block}' が正しくありません。恐らく '${correct}' ではないでしょうか。"]);
					} else {
						push(@valid_blocks, $block);
					}
				} else {
					push(@errs, [$k, "\"許可するIPアドレス\"に指定したアドレスブロック '${block}' が正しくありません。"]);
				}
				push(@blocks, $block);
			}
			$in->{$k} = join("\n", @blocks);
			if(@valid_blocks) {
				my $allow_flag = 0;
				for my $block (@valid_blocks) {
					if( my $allow = Net::Netmask->new($block)->match($ENV{REMOTE_ADDR}) ) {
						$allow_flag = 1;
						last;
					}
				}
				unless($allow_flag) {
					push(@errs, [$k, "\"許可するIPアドレス\"に指定したアドレスブロックに、あなたのアクセス元IPアドレス（$ENV{REMOTE_ADDR}）が含まれておりません。"]);
				}
			}
		#パスワードロック回数
		} elsif($k eq "pass_lock_limit") {
			if($v ne "") {
				if($v =~ /[^0-9]/) {
					push(@errs, [$k, "\"パスワードロック\"は半角数字で指定してください。"]);
				} elsif($v < 1 || $v > 99) {
					push(@errs, [$k, "\"パスワードロック\"は1～99の値をセットしてください。"]);
				}
			}
		#ログオンセッション有効期間
		} elsif($k eq "session_expire") {
			if($v) {
				if($v =~ /[^\d]/) {
					push(@errs, [$k, "\"ログオンセッション有効期間\"は半角数字で指定してください。"]);
				} elsif($v < 1 || $v > 999) {
					push(@errs, [$k, "\"ログオンセッション有効期間\"は1～999時間の間で指定してください。"]);
				}
			} else {
				push(@errs, [$k, "\"ログオンセッション有効期間\"は必須です。"]);
			}
		#自動ログオン
		} elsif($k eq "auto_logon") {
			if($v) {
				if($v ne "1") {
					push(@errs, [$k, "\"自動ログオン\"に不正な値が送信されました。"]);
				}
			}
		#staticディレクトリのURL
		} elsif($k eq "static_url") {
			if($v) {
				if($v =~ /[^a-zA-Z\/\.\_\-]/) {
					push(@errs, [$k, "\"staticディレクトリのURL\"に不正な文字が含まれています。"]);
				}
			} else {
				push(@errs, [$k, "\"staticディレクトリのURL\"は必須です。"]);
			}
		#sendmailのパス
		} elsif($k eq "sendmail_path") {
			if($v) {
				if($v =~ /[^a-zA-Z\/\.\_\-]/) {
					push(@errs, [$k, "\"sendmailのパス\"に不正な文字が含まれています。"]);
				} elsif($v !~ /\/sendmail$/) {
					push(@errs, [$k, "\"sendmailのパス\"にsendmailコマンド以外の名前を指定することはできません。"]);
				} elsif( ! -e $v) {
					push(@errs, [$k, "\"sendmailのパス\"に指定したパスにsendmailコマンドが見つかりませんでした。"]);
				} elsif( ! -x $v) {
					push(@errs, [$k, "\"sendmailのパス\"に指定したsendmailコマンドに実行権限がありません。"]);
				}
			}
		#SMTPサーバ
		} elsif($k eq "smtp_host") {
			if($in->{sendmail_path}) {
				if($v ne "") {
					push(@errs, [$k, "\"SMTPサーバ\"を指定する場合は、\"sendmailのパス\"に何も指定しないでください。"]);
				}
			} else {
				if($v ne "") {
					if($v =~ /[^0-9a-zA-Z\-\.]/) {
						push(@errs, [$k, "\"SMTPサーバ\"が正しくありません。"]);
					}
				}
			}
		#SMTPポート番号
		} elsif($k eq "smtp_port") {
			if($in->{smtp_host} && $v eq "") {
				push(@errs, [$k, "\"SMTPポート番号\"を指定してください。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "\"SMTPポート番号\"は半角数字で指定してください。"]);
			}
		#SMTP認証のユーザー名
		} elsif($k eq "smtp_auth_user") {
			if($v ne "") {
				if($v =~ /[^\x21-\x7e]/) {
					push(@errs, [$k, "\"SMTP認証のユーザー名\"は半角文字で指定してください。"]);
				}
			} elsif($v eq "" && $in->{smtp_auth_pass} ne "") {
				push(@errs, [$k, "\"SMTP認証のユーザー名\"を指定してください。"]);
			}
		#SMTP認証のパスワード
		} elsif($k eq "smtp_auth_pass") {
			if($v ne "") {
				if($v =~ /[^\x21-\x7e]/) {
					push(@errs, [$k, "\"SMTP認証のパスワード\"は半角文字で指定してください。"]);
				}
			} elsif($v eq "" && $in->{smtp_auth_user} ne "") {
				push(@errs, [$k, "\"SMTP認証のパスワード\"を指定してください。"]);
			}
		#通知メール送信先アドレス
		} elsif($k eq "notice_to") {
			if($v ne "") {
				if( ! Email::Valid->rfc822($v) ) {
					push(@errs, [$k, "\"通知メール送信先アドレス\"が正しくありません。"]);
				}
			}
		#通知メール差出人アドレス
		} elsif($k eq "notice_from") {
			if($v eq "") {
				$in->{$k} = $in->{notice_to};
			} else {
				if( ! Email::Valid->rfc822($v) ) {
					push(@errs, [$k, "\"通知メール差出人アドレス\"が正しくありません。"]);
				}
			}
		#タイムゾーン
		} elsif($k eq "tz") {
			if($v ne "") {
				my $zones = Time::ZoneInfo->new();
				if( ! $zones || ! $zones->zones || ref($zones->zones) ne "ARRAY" || ! @{$zones->zones} ) {
					push(@errs, [$k, "ご利用のサーバでは\"タイムゾーン\"を指定することはできません。"]);
				} elsif( ! grep(/^\Q${v}\E/, @{$zones->zones}) && $v !~ /^[\+\-]\d{4}$/) {
					push(@errs, [$k, "\"タイムゾーン\"に不正な値が送信されました。"]);
				}
			}
		}
	}
	#SMTP接続チェック
	if( ! @errs && $in->{smtp_host} ne "" && $in->{smtp_port} ne "" ) {
		my $smtp;
		if($in->{smtp_auth_user} && $in->{smtp_auth_pass}) {
			$smtp = Mail::SendEasy::SMTP->new($in->{smtp_host}, $in->{smtp_port} , $self->{conf}->{smtp_timeout}, $in->{smtp_auth_user}, $in->{smtp_auth_pass}) ;
			if( ! $smtp ) {
				push(@errs, ["smtp_host", "SMTP接続に失敗しました。$@"])
			}
			if( ! @errs &&  ! $smtp->auth ) {
				push(@errs, ["smtp_host", "SMTP接続に失敗しました。$smtp->last_response_line"])
			}
		} else {
			$smtp = Mail::SendEasy::SMTP->new($in->{smtp_host}, $in->{smtp_port} , $self->{conf}->{smtp_timeout}) ;
			if( ! $smtp ) {
				push(@errs, ["smtp_host", "SMTP接続に失敗しました。$@"])
			}
		}
		if($smtp) {
			$smtp->close;
		}
	}
	#
	return @errs;
}

1;
