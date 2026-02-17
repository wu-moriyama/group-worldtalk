package FCC::View::Mypage::DslfledwnView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
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
	my $dsl = $context->{dsl};
	if($dsl->{dwn_loc} == 1) {
		my $dwn_fname = $dsl->{dwn_fname};
		my $dwn_fsize = $dsl->{dwn_fsize};
		open my $fh, "<", $dsl->{dwn_fpath};
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
	} elsif($dsl->{dwn_loc} == 2) {
		my $url = $dsl->{dwn_url};
		print "Location: ${url}\n\n";
	} else {
		$self->error(["parameter error"]);
		exit;
	}
}

1;
