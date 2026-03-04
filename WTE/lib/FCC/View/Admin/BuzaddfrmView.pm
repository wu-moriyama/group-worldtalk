package FCC::View::Admin::BuzaddfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

sub dispatch {
    my ( $self, $context ) = @_;

    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    my $t = $self->load_template();

    my $prof_id = $context->{prof_id} || '';

    my @prof_loop;
    for my $p ( @{ $context->{prof_loop} || [] } ) {
        my %h = ( prof_id => $p->{prof_id}, prof_handle => CGI::Utils->new()->escapeHtml( $p->{prof_handle} || '' ) );
        $h{selected} = 'selected' if ( $prof_id ne '' && $p->{prof_id} == $prof_id );
        push @prof_loop, \%h;
    }
    $t->param( prof_loop => \@prof_loop );
    $t->param( prof_id   => CGI::Utils->new()->escapeHtml($prof_id) );
    $t->param( buzadd_error => $context->{buzadd_error} ? 1 : 0 );
    $t->param( buzadd_msg   => $context->{buzadd_msg} ? CGI::Utils->new()->escapeHtml( $context->{buzadd_msg} ) : '' );
    $t->param( buzadd_ok    => $context->{buzadd_ok} ? 1 : 0 );

    $self->print_html($t);
}

1;
