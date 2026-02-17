package FCC::View::Prof::BilpdmsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#プロセスキー
	my $pkey = $context->{proc}->{pkey};
	my $rurl = $self->{conf}->{CGI_URL} . "?m=bilpdmcpt&pkey=${pkey}";
	print "Location: ${rurl}\n\n";
}

1;
