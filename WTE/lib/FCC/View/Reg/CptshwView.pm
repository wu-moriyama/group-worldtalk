package FCC::View::Reg::CptshwView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Reg::_SuperView);
use CGI::Utils;

sub dispatch {
    my ( $self, $context ) = @_;
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        return;
    }
    my $lang = $context->{lang};
    my $t    = $self->load_template( undef, $lang );
    while ( my ( $k, $v ) = each %{ $context->{seller} } ) {
        $t->param( "session_${k}" => CGI::Utils->new()->escapeHtml($v) );
    }
    #
    my $cookie_string_list = $self->{session}->logoff_cookie_strings();
    my $hdrs               = { "Set-Cookie" => $cookie_string_list };
    $self->print_html( $t, $hdrs );
}

1;
