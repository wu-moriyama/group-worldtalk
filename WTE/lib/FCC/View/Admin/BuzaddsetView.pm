package FCC::View::Admin::BuzaddsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
    my ( $self, $context ) = @_;

    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    if ( $context->{redirect_url} ) {
        print "Location: $context->{redirect_url}\n\n";
        return;
    }

    print "Location: " . $self->{conf}->{CGI_URL} . "?m=buzlstfrm\n\n";
}

1;
