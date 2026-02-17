package FCC::View::Admin::DctsdnsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	my $rurl = $self->{conf}->{CGI_URL} . "?m=dctlstfrm";
	print "Location: ${rurl}\n\n";
}

1;
