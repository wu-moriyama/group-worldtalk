package FCC::View::Admin::CoumodfrmtestmailView;
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

    # 通常は redirect_url がセットされている
    print "Location: " . $self->{conf}->{CGI_URL} . "?m=coumodfrm\n\n";
}

1;
