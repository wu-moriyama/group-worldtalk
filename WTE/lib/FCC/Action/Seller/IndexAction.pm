package FCC::Action::Seller::IndexAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use CGI::Cookie;
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#自動ログオンフラグ
	if($self->{session}->{data}->{auto_login_enable}) {
		my %cookies = fetch CGI::Cookie;
		if($cookies{"$self->{conf}->{FCC_SELECTOR}_auto_logon_enable"}) {
			$context->{auto_logon_enable} = 1;
		}
	}
	#代理店情報を取得
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($seller_id);
	if( ! $seller || ref($seller) ne "HASH" || ! $seller->{seller_id} ) {
		$self->{session}->logoff();
		$context->{fatalerrs} = ["あなたのアカウントは現在ご利用頂けません。"];
		return $context;
	}
	#代理店ステータスをチェック
	if($seller->{seller_status} != 1) {
		$self->{session}->logoff();
		$context->{fatalerrs} = ["あなたのアカウントは現在ご利用頂けません。"];
		return $context;
	}
	#セッションIDを変更
	$self->{session}->recreate($seller);
	#
	return $context;
}

1;
