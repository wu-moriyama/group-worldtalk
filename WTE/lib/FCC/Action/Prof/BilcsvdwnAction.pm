package FCC::Action::Prof::BilcsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use CGI::Utils;
use FCC::Class::Pdm;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	#
	my $params = {};
	$params->{prof_id} = $prof_id;
	$params->{sort} = [['lsn_stime', 'DESC']];
	$params->{charcode} = "sjis";
	$params->{returncode} = "\x0a";
	#レッスン情報を検索
	my $opdm = new FCC::Class::Pdm(conf=>$self->{conf}, db=>$self->{db});
	my $res = $opdm->get_lsn_csv($params);
	#
	$context->{res} = $res;
	return $context;
}


1;
