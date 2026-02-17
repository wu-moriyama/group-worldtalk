package FCC::Action::Mypage::AthlinsmtAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;
use FCC::Class::String::Checker;
use FCC::Class::Login;
use FCC::Class::Log;
use FCC::Class::PasswdHash;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力されたID/パスワードを取得
	my $in_names = ['member_email', 'member_pass', 'auto_login_enable'];
	my $in = $self->get_input_data($in_names);
	#自動ログイン
	if($in->{auto_login_enable} ne "1") {
		$in->{auto_login_enable} = 0;
	}
	#コンテキストにパラメータをセット
	$context->{in} = $in;
	#Cookieのテスト
	my %cookies = fetch CGI::Cookie;
	#入力値をチェック
	if( ! $in->{member_email} ) {
		$context->{errs} = [["member_email", "メールアドレスを入力してください。"]];
		return $context;
	}
	if( ! $in->{member_pass} ) {
		$context->{errs} = [["member_pass", "パスワードを入力してください。"]];
		return $context;
	}
	#
	my $auth_err_msg = "認証エラーです。メールアドレスとパスワードを確認してください。";
	#文字長チェック
	if( length($in->{member_email}) > 255 || length($in->{member_pass}) > 255 ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	if( length($in->{member_pass}) < 8 ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#ASCII文字以外が含まれていたらNG
	if( length($in->{member_email}) =~ /[^\x21-\x7e]/ || length($in->{member_pass}) =~ /[^\x21-\x7e]/ ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#メールアドレスが不適切ならNG
	unless( FCC::Class::String::Checker->new($in->{member_email})->is_mailaddress() ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#メールアドレスから会員情報を取得
	my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db})->get_from_db_by_email($in->{member_email});
	if( ! $member || ref($member) ne "HASH" || ! $member->{member_id} ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#会員ステータスをチェック
	if($member->{member_status} != 1) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#会員パスワードを照合
	unless(FCC::Class::PasswdHash->new()->validate($in->{member_pass}, $member->{member_pass})) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#認証OK
	$self->{session}->create($member, $in->{auto_login_enable});
	#ログイン日時を記録
	FCC::Class::Login->new(conf=>$self->{conf}, db=>$self->{db})->add({
		member_id => $member->{member_id},
		lin_date  => time,
		lin_type  => 1
	});
	#
	my $target = $self->{q}->param("target");
	if($target !~ /^[a-z][a-z0-9]+$/) {
		$target = "";
	}
	$context->{target} = $target;
	#リダイレクトURLの絶対パス
	my $redirect = $self->{q}->param("redirect");
	if($redirect && $redirect !~ /^\/[a-zA-Z0-9\/\_\.\-\%\&\=\?]+$/) {
		$redirect = "";
	}
	$context->{redirect} = $redirect;
	$context->{member} = $member;
	#
	return $context;
}

1;
