package FCC::View::Admin::CctlstajxView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use JSON;

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }
    my $json_str = JSON::to_json( $context->{list} );
    my $clen     = length($json_str);
    print "Content-Type: application/json\n";
    print "Content-Length: ${clen}\n";
    print "\n";
    print $json_str;
}

1;
