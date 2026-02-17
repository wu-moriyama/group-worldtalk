package FCC::Action::Admin::BsecnffrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Syscnf;

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $pkey    = $self->{q}->param("pkey");
    my $proc    = $self->get_proc_session_data( $pkey, "bsecnf" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("bsecnf");
        $proc->{in} = $self->{conf};
    }
    #
    $context->{proc} = $proc;
    return $context;
}

1;
