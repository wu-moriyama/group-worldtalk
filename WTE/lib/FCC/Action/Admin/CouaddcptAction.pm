package FCC::Action::Admin::CouaddcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $pkey    = $self->{q}->param("pkey");
    my $proc    = $self->get_proc_session_data( $pkey, "couadd" );
    my $in      = {};
    while ( my ( $k, $v ) = each %{ $proc->{course} } ) {
        $in->{$k} = $v;
    }
    $self->del_proc_session_data();
    $context->{in} = $in;
    return $context;
}

1;
