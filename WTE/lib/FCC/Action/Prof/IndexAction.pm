package FCC::Action::Prof::IndexAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use CGI::Cookie;
use FCC::Class::Prof;

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
	#講師情報を取得
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($prof_id);
	if( ! $prof || ref($prof) ne "HASH" || ! $prof->{prof_id} ) {
		$self->{session}->logoff();
		$context->{fatalerrs} = ["あなたのアカウントは現在ご利用頂けません。"];
		return $context;
	}
	#講師ステータスをチェック
#	if($prof->{prof_status} != 1) {
#		$self->{session}->logoff();
#		$context->{fatalerrs} = ["あなたのアカウントは現在ご利用頂けません。"];
#		return $context;
#	}
	#セッションIDを変更
	$self->{session}->recreate($prof);
	#
	return $context;
}

1;
