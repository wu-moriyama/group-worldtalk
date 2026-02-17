package FCC::Action::Seller::AthlinsmtAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use FCC::Class::Seller;
use FCC::Class::String::Checker;
use FCC::Class::PasswdHash;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力されたID/パスワードを取得
	my $in_names = ['seller_email', 'seller_pass', 'auto_login_enable'];
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
	if( ! $in->{seller_email} ) {
		$context->{errs} = [["seller_email", "メールアドレスを入力してください。"]];
		return $context;
	}
	if( ! $in->{seller_pass} ) {
		$context->{errs} = [["seller_pass", "パスワードを入力してください。"]];
		return $context;
	}
	#
	my $auth_err_msg = "認証エラーです。メールアドレスとパスワードを確認してください。";
	#文字長チェック
	if( length($in->{seller_email}) > 255 || length($in->{seller_pass}) > 255 ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	if( length($in->{seller_pass}) < 8 ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#ASCII文字以外が含まれていたらNG
	if( length($in->{seller_email}) =~ /[^\x21-\x7e]/ || length($in->{seller_pass}) =~ /[^\x21-\x7e]/ ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#メールアドレスが不適切ならNG
	unless( FCC::Class::String::Checker->new($in->{seller_email})->is_mailaddress() ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#メールアドレスから営業会社情報を取得
	my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db_by_email($in->{seller_email});
	if( ! $seller || ref($seller) ne "HASH" || ! $seller->{seller_id} ) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#営業会社ステータスをチェック
	if($seller->{seller_status} != 1) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#営業会社パスワードを照合
	unless(FCC::Class::PasswdHash->new()->validate($in->{seller_pass}, $seller->{seller_pass})) {
		$context->{errs} = [["", $auth_err_msg]];
		return $context;
	}
	#認証OK
	$self->{session}->create($seller, $in->{auto_login_enable});
	#
	return $context;
}

1;
