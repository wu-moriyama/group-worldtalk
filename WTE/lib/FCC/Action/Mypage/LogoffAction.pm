package FCC::Action::Mypage::LogoffAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Login;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member = $self->{session}->{data}->{member};
	#ログオフ処理
	$self->{session}->logoff();
	#ログオフ記録
	FCC::Class::Login->new(conf=>$self->{conf}, db=>$self->{db})->add({
		member_id => $member->{member_id},
		lin_date  => time,
		lin_type  => 2
	});
	#リダイレクトURLの絶対パス
	my $redirect = $self->{q}->param("r");
	if($redirect && $redirect !~ /^\/[a-zA-Z0-9\/\_\.\-\%\&\=\?]+$/) {
		$redirect = "";
	}
	#
	$context->{redirect} = $redirect;
	$context->{member} = $member;
	return $context;
}

1;
