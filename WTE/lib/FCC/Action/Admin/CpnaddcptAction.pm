package FCC::Action::Admin::CpnaddcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $pkey    = $self->{q}->param("pkey");
    my $proc    = $self->get_proc_session_data( $pkey, "cpnadd" );
    my $in      = {};
    while ( my ( $k, $v ) = each %{ $proc->{coupon} } ) {
        $in->{$k} = $v;
    }
    my $seller = FCC::Class::Seller->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} )->get_from_db( $in->{seller_id} );
    $self->del_proc_session_data();
    #
    $context->{in}     = $in;
    $context->{seller} = $seller;
    return $context;
}

1;
