package FCC::View::Admin::PntcnttsvdwnView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}

	my $filename = $context->{fname};
	my $len = $context->{length};

	print "Content-Type: application/octet-stream\n";
	print "Content-Disposition: attachment; filename=${filename}\n";
	print "Content-Length: ${len}\n";
	print "\n";
	print $context->{csv};
}

1;
