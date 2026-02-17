package FCC::Action::Admin::PrfdelcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $pkey    = $self->{q}->param("pkey");
    my $proc    = $self->get_proc_session_data( $pkey, "prfdel" );
    my $proc2   = { prof => {} };
    while ( my ( $k, $v ) = each %{ $proc->{prof} } ) {
        $proc2->{prof}->{$k} = $v;
    }
    $self->del_proc_session_data();
    $context->{proc} = $proc2;
    return $context;
}

1;
