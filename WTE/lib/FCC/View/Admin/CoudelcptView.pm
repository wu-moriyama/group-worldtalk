package FCC::View::Admin::CoudelcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);

sub dispatch {
    my ( $self, $context ) = @_;
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
    }
    my $t = $self->load_template();
    while ( my ( $k, $v ) = each %{ $context->{proc}->{course} } ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
    }
    $self->print_html($t);
}

1;
