package FCC::Action::Mypage::AthlinfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#
	my $seller_id = $self->{q}->param("s");
	if( ! $seller_id || $seller_id =~ /[^\d]/ ) {
		#$context->{fatalerrs} = ["不正なリクエストです。"];
		#return $context;
		$seller_id = 0;
	}
	my $seller = { seller_id =>$seller_id };
	if($seller_id) {
		my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		$seller = $oseller->get($seller_id);
		if( ! $seller || $seller->{seller_status} != 1 ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$context->{seller} = $seller;
	}
	#
	my $target = $self->{q}->param("target");
	if($target =~ /^[a-z][a-z0-9]+$/) {
		$context->{target} = $target;
	}
	my $redirect = $self->{q}->param("r");
	if($redirect) {
		$context->{redirect} = $redirect;
	}

	my $lang = $self->{q}->param("lang");
	if($lang ne "2") {
		$lang = "1";
	}
	$context->{lang} = $lang;
	#
	return $context;
}

1;
