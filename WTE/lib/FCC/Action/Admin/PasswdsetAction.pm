package FCC::Action::Admin::PasswdsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Passwd;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "passwd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力されたID/パスワードを取得
	$proc->{in} = $self->get_input_data(['id', 'pass1', 'pass2']);
	#IDをチェック
	my $pw = new FCC::Class::Passwd(conf=>$self->{conf});
	unless($pw) {
		$context->{fatalerrs} = [$!];
		return $context;
	}
	my $id_chk = $pw->check_id($proc->{in}->{id});
	#エラー
	my @errs;
	if($id_chk) {
		if($id_chk == 1) {
			push(@errs, '管理者IDを入力してください。');
		} elsif($id_chk == 2) {
			push(@errs, '管理者IDは3文字以上でなければいけません。');
		} elsif($id_chk == 3) {
			push(@errs, '管理者IDは255文字以下でなければいけません。');
		} elsif($id_chk == 4) {
			push(@errs, '管理者IDは半角英数字および半角記号で指定してください。');
		}
	}
	if($proc->{in}->{pass1} && $proc->{in}->{pass2}) {
		if($proc->{in}->{pass1} ne $proc->{in}->{pass2}) {
			push(@errs, 'パスワードが違います。');
		} else {
			my $pw_chk = $pw->check_pass($proc->{in}->{pass1});
			if($pw_chk) {
				if($pw_chk == 1) {
					push(@errs, 'パスワードを入力してください。');
				} elsif($pw_chk == 2) {
					push(@errs, 'パスワードは3文字以上でなければいけません。');
				} elsif($pw_chk == 3) {
					push(@errs, 'パスワードは255文字以下でなければいけません。');
				} elsif($pw_chk == 4) {
					push(@errs, 'パスワードは半角英数字および半角記号で指定してください。');
				}
			}
		}
	} else {
		push(@errs, 'パスワードを入力してください。');
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		#パスワード情報をセット
		$pw->replace( $self->{session}->{data}->{id}, $proc->{in}->{id}, { pass=>$proc->{in}->{pass1} });
	}
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
