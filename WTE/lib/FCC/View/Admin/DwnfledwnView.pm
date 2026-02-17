package FCC::View::Admin::DwnfledwnView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#
	my $dwn = $context->{dwn};
	my $dwn_fname = $dwn->{dwn_fname};
	my $dwn_fsize = $dwn->{dwn_fsize};
	open my $fh, "<", $dwn->{dwn_fpath};
	binmode($fh);
	print "Content-Type: application/octet-stream\n";
	print "Content-Disposition: attachment; filename=${dwn_fname}\n";
	print "Content-Length: ${dwn_fsize}\n";
	print "\n";
	my $buff;
	while ( my $len = sysread($fh, $buff, 1048576)) {
		print $buff;
	}
	close($fh);
}

1;
