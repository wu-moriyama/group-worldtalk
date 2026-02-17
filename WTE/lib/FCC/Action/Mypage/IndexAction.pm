package FCC::Action::Mypage::IndexAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use CGI::Cookie;
use FCC::Class::Member;

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
	#会員情報を取得
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db})->get_from_db($member_id);
	if( ! $member || ref($member) ne "HASH" || ! $member->{member_id} ) {
		$self->{session}->logoff();
		$context->{fatalerrs} = ["あなたのアカウントは現在ご利用頂けません。"];
		return $context;
	}
	#会員ステータスをチェック
	if($member->{member_status} != 1) {
		$self->{session}->logoff();
		$context->{fatalerrs} = ["あなたのアカウントは現在ご利用頂けません。"];
		return $context;
	}
	#セッションIDを変更
	$self->{session}->recreate($member);
	#セッション更新
	$self->{session}->update({member=>$member});
	#
	return $context;
}

1;
