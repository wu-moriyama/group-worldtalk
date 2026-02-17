package FCC::View::Admin::CctdelajxView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use JSON;

sub dispatch {
    my ( $self, $context ) = @_;
    my $body;
    my $status;

    if ( $context->{fatalerrs} ) {
        $body   = { message => $context->{fatalerrs}->[0] };
        $status = "500 Internal Server Error";
    }
    else {
        $body   = $context->{res};
        $status = "200 OK";
    }

    my $json_str = JSON::to_json($body);
    my $clen     = length($json_str);

    print "Content-Type: application/json\n";
    print "Status: ${status}\n";
    print "Content-Length: ${clen}\n";
    print "\n";
    print $json_str;
}

1;
