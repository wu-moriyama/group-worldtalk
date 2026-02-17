package FCC::View::Mypage::FavsetajxView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->print_text($context->{fatalerrs}->[0]);
	}
	#
	$self->print_text($context->{return_value});
}

sub print_text {
	my($self, $text) = @_;
	my $len = length $text;
	print "Content-Type: text/plain; charset=utf-8\n";
	print "Content-Length: ${len}\n";
	print "\n";
	print $text;
}

1;
