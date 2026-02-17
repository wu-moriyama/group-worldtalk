package FCC::Action::Prof::AthlinsmtAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::String::Checker;
use FCC::Class::PasswdHash;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力されたID/パスワードを取得
	my $in_names = ['prof_email', 'prof_pass', 'auto_login_enable'];
	my $in = $self->get_input_data($in_names);
	#自動ログイン
	if($in->{auto_login_enable} ne "1") {
		$in->{auto_login_enable} = 0;
	}
	#コンテキストにパラメータをセット
	$context->{in} = $in;
	#Cookieのテスト
	my %cookies = fetch CGI::Cookie;
	unless($cookies{"test"} && $cookies{"test"}->value eq "1") {
		$context->{errs} = [["", "ご利用のブラウザーはCookieを拒否しているため、ログインできません。"]];
		return $context;
	}
	#入力値をチェック
	if( ! $in->{prof_email} ) {
		$context->{errs} = [["prof_email", "メールアドレスを入力してください。"]];
		return $context;
	}
	if( ! $in->{prof_pass} ) {
		$context->{errs} = [["prof_pass", "パスワードを入力してください。"]];
		return $context;
	}
	#
	my $auth_err_msg = "認証エラーです。メールアドレスとパスワードを確認してください。";
	#文字長チェック
	if( length($in->{prof_email}) > 255 || length($in->{prof_pass}) > 255 ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	if( length($in->{prof_pass}) < 8 ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#ASCII文字以外が含まれていたらNG
	if( length($in->{prof_email}) =~ /[^\x21-\x7e]/ || length($in->{prof_pass}) =~ /[^\x21-\x7e]/ ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#メールアドレスが不適切ならNG
	unless( FCC::Class::String::Checker->new($in->{prof_email})->is_mailaddress() ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#メールアドレスから講師情報を取得
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db_by_email($in->{prof_email});
	if( ! $prof || ref($prof) ne "HASH" || ! $prof->{prof_id} ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#講師ステータスをチェック
#	if($prof->{prof_status} != 1) {
#		$context->{errs} = [["", $auth_err_msg]];
#		return $context;
#	}
	#講師パスワードを照合
	unless(FCC::Class::PasswdHash->new()->validate($in->{prof_pass}, $prof->{prof_pass})) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#認証OK
	$self->{session}->create($prof, $in->{auto_login_enable});
	#
	return $context;
}

1;
