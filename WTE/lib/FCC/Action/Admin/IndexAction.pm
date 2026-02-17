package FCC::Action::Admin::IndexAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Cookie;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#自動ログオンフラグ
	if($self->{conf}->{auto_logon}) {
		my %cookies = fetch CGI::Cookie;
		if($cookies{"$self->{conf}->{FCC_SELECTOR}_auto_logon_enable"}) {
			$context->{auto_logon_enable} = 1;
		}
	}
	#セッションIDを変更
	$context->{sid} = $self->{session}->recreate();
	unless($context->{sid}) {
		my $err = $self->{session}->error();
		$context->{fatalerrs} = [$err];
	}
	#
	return $context;
}

1;
