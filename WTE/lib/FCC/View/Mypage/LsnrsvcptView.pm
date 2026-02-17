package FCC::View::Mypage::LsnrsvcptView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;

sub dispatch {
    my ( $self, $context ) = @_;
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        return;
    }
    my $t = $self->load_template();
    while ( my ( $k, $v ) = each %{ $context->{in} } ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
        if ( $k =~ /_(fee|coupon|point)$/ ) {
            $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
        }
        elsif ( $k eq "lsn_pay_type" ) {
            $t->param( "${k}_${v}" => 1 );
        }
    }
    $self->print_html($t);
}

1;
