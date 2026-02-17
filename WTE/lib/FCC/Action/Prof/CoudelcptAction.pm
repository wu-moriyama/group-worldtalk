package FCC::Action::Prof::CoudelcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $pkey    = $self->{q}->param("pkey");
    my $proc    = $self->get_proc_session_data( $pkey, "coudel" );
    my $proc2   = { course => {} };
    while ( my ( $k, $v ) = each %{ $proc->{course} } ) {
        $proc2->{course}->{$k} = $v;
    }
    $self->del_proc_session_data();
    $context->{proc} = $proc2;
    return $context;
}

1;
