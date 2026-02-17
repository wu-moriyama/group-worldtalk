package FCC::View::Admin::BsecnffrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    #テンプレートのロード
    my $t = $self->load_template();
    $t->param( "pkey" => $context->{proc}->{pkey} );
    while ( my ( $k, $v ) = each %{ $context->{proc}->{in} } ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
        if ( $k =~ /^(lesson_reservation_limit_unit)/ ) {
            $t->param( "${k}_${v}_selected" => 'selected="selected"' );
        }
    }

    #プロセスエラー
    my %err_names;
    if ( @{ $context->{proc}->{errs} } ) {
        my $errs = "<ul>";
        for my $e ( @{ $context->{proc}->{errs} } ) {
            $t->param( "$e->[0]_err" => "err" );
            $errs .= "<li>$e->[1]</li>";
            $err_names{ $e->[0] } = "err";
        }
        $errs .= "</ul>";
        $t->param( 'errs' => $errs );
    }

    #各種選択項目
    for my $name ( 'member_purpose', 'member_demand', 'member_interest', 'member_level', 'prof_character', 'prof_interest', 'prof_rank' ) {
        my @loop;
        my $max = $self->{conf}->{"${name}_num"};
        for ( my $id = 1 ; $id <= $max ; $id++ ) {
            my $h = {
                id    => $id,
                title => CGI::Utils->new()->escapeHtml( $context->{proc}->{in}->{"${name}${id}_title"} ),
                err   => $err_names{"${name}${id}_title"}
            };
            push( @loop, $h );
        }
        $t->param( "${name}_loop" => \@loop );
    }
    #
    $self->print_html($t);
}

1;
