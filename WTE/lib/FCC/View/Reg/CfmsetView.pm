package FCC::View::Reg::CfmsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Reg::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	#プロセスキー
	my $pkey = $context->{proc}->{pkey};
	#
	if(@{$context->{proc}->{errs}}) {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=frmshw&pkey=${pkey}";
		print "Location: ${rurl}\n\n";
	} else {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=cfmshw&pkey=${pkey}";
		print "Location: ${rurl}\n\n";
	}


}

1;
