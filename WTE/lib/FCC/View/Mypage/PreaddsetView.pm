package FCC::View::Mypage::PreaddsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#
	my $lsn_id = $context->{lsn_id};
	my $rurl = $self->{conf}->{CGI_URL} . "?m=parent";
	print "Location: ${rurl}\n\n";
}

1;
