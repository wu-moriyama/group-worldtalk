package FCC::View::Prof::MsgaddsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#
	my $lsn_id = $context->{lsn_id};
	my $rurl = $self->{conf}->{CGI_URL} . "?m=lsndtlfrm&lsn_id=${lsn_id}";
	print "Location: ${rurl}\n\n";
}

1;
