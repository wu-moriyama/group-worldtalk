package FCC::Action::Mypage::MpgshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Mypg;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $mypg_id = $self->{q}->param("mypg_id");
	if( ! defined $mypg_id || $mypg_id eq "" || $mypg_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#ページを取得
	my $omypg = new FCC::Class::Mypg(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $mypg = $omypg->get($mypg_id);
	if( ! $mypg ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	$context->{mypg} = $mypg;
	return $context;
}

1;
