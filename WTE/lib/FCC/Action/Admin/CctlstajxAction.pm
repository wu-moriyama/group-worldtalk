package FCC::Action::Admin::CctlstajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Ccate;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $occate =
      new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    my $list = $occate->get_children( { ccate_id => 0 } );

    $context->{list} = $list;
    return $context;
}

1;
