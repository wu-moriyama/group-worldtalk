package FCC::View::Prof::CouaddsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    #プロセスキー
    my $pkey = $context->{proc}->{pkey};
    #
    if ( @{ $context->{proc}->{errs} } ) {
        my $rurl = $self->{conf}->{CGI_URL} . "?m=couaddfrm&pkey=${pkey}";
        print "Location: ${rurl}\n\n";
    }
    else {
        my $rurl = $self->{conf}->{CGI_URL} . "?m=couaddcpt&pkey=${pkey}";
        print "Location: ${rurl}\n\n";
    }
}

1;
