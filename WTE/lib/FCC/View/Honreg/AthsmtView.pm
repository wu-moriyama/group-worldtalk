package FCC::View::Honreg::AthsmtView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Honreg::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self, $context) = @_;
	my $seller_id = $context->{seller}->{seller_id};
	unless($seller_id) {
		$seller_id = 0;
	}
	my $member_id = $context->{member_id};
	my $lang = $context->{lang};

	if($context->{err}) {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=errshw&lang=${lang}&s=${seller_id}&err=$context->{err}";
		print "Location: ${rurl}\n\n";
	} else {
		my $rurl = $self->{conf}->{CGI_URL} . "?m=cptshw&lang=${lang}&s=${seller_id}&mb=${member_id}";
		print "Location: ${rurl}\n\n";
	}
}

1;
