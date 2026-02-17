package FCC::Action::Seller::BilcsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use CGI::Utils;
use FCC::Class::Sdm;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	#
	my $params = {};
	$params->{seller_id} = $seller_id;
	$params->{sort} = [['lsn_stime', 'DESC']];
	$params->{charcode} = "sjis";
	$params->{returncode} = "\x0a";
	#レッスン情報を検索
	my $osdm = new FCC::Class::Sdm(conf=>$self->{conf}, db=>$self->{db});
	my $res = $osdm->get_lsn_csv($params);
	#
	$context->{res} = $res;
	return $context;
}


1;
