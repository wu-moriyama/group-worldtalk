package FCC::Action::Admin::BuztglajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Buzz;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#クチコミ識別IDを取得
	my $buz_id = $self->{q}->param("buz_id");
	if( ! defined $buz_id || $buz_id eq "" || $buz_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#クチコミ情報を取得
	my $obuz = new FCC::Class::Buzz(conf=>$self->{conf}, db=>$self->{db});
	my $buz = $obuz->get($buz_id);
	if( ! $buz ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#buz_show
	my $buz_show = $buz->{buz_show} ? 0 : 1;
	#アップデート
	$obuz->set_buz_show($buz_id, $buz_show);
	#
	$buz->{buz_show} = $buz_show;
	$context->{buz} = $buz;
	return $context;
}


1;
