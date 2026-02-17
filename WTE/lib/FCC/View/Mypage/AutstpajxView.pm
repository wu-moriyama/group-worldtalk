package FCC::View::Mypage::AutstpajxView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	my $len = length $context->{return_value};
	print "Content-Type: text/plain; charset=utf-8\n";
	print "Content-Length: ${len}\n";
	print "\n";
	print $context->{return_value};
}

1;
