package FCC::Action::Seller::TopAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use FCC::Class::Seller;
use FCC::Class::Ann;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	#
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $seller = $oseller->get_from_db($seller_id);
	#‚¨’m‚ç‚¹‚ğæ“¾
	my $oann = new FCC::Class::Ann(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $ann_list = $oann->get_list_for_dashboard(1);
	#
	$context->{seller} = $seller;
	$context->{ann_list} = $ann_list;
	return $context;
}

1;
