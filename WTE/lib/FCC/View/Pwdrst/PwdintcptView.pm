package FCC::View::Pwdrst::PwdintcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Pwdrst::_SuperView);
use CGI::Utils;

sub dispatch {
    my ( $self, $context ) = @_;
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        return;
    }

    my $lang               = $context->{lang};
    my $t                  = $self->load_template( undef, $lang );
    my $cookie_string_list = $self->{session}->logoff_cookie_strings();
    my $hdrs               = { "Set-Cookie" => $cookie_string_list };
    $self->print_html( $t, $hdrs );
}

1;
