package FCC::View::Admin::PrfdelfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

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

    #講師情報
    while ( my ( $k, $v ) = each %{ $context->{proc}->{prof} } ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
        if ( $k =~ /^(prof_cdate|prof_mdate)$/ ) {
            my @tm = FCC::Class::Date::Utils->new( time => $v, tz => $self->{conf}->{tz} )->get(1);
            for ( my $i = 0 ; $i <= 9 ; $i++ ) {
                $t->param( "${k}_${i}" => $tm[$i] );
            }
        }
        elsif ( $k =~ /^prof_(gender|status|card|reco|coupon_ok)$/ ) {
            $t->param( "${k}_${v}" => 1 );
        }
        elsif ( $k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note)$/ ) {
            my $tmp = CGI::Utils->new()->escapeHtml($v);
            $tmp =~ s/\n/<br \/>/g;
            $t->param( $k => $tmp );
        }
        elsif ( $k eq "prof_rank" ) {
            my $title = $self->{conf}->{"prof_rank${v}_title"};
            $t->param( "${k}_title" => CGI::Utils->new()->escapeHtml($title) );
        }
    }

    #特徴/興味
    for my $k ( 'prof_character', 'prof_interest' ) {
        my $v    = $context->{proc}->{prof}->{$k} + 0;
        my $bin  = unpack( "B32", pack( "N", $v ) );
        my @bits = split( //, $bin );
        my @loop;
        for ( my $id = 1 ; $id <= $self->{conf}->{"${k}_num"} ; $id++ ) {
            my $title   = $self->{conf}->{"${k}${id}_title"};
            my $checked = "";
            if     ( $title eq "" )  { next; }
            unless ( $bits[ -$id ] ) { next; }
            my $h = {
                id    => $id,
                title => CGI::Utils->new()->escapeHtml($title)
            };
            push( @loop, $h );
        }
        $t->param( "${k}_loop" => \@loop );
    }

    #プロセスエラー
    if ( defined $context->{proc}->{errs} && @{ $context->{proc}->{errs} } ) {
        my $errs = "<ul>";
        for my $e ( @{ $context->{proc}->{errs} } ) {
            $t->param( "$e->[0]_err" => "err" );
            $errs .= "<li>$e->[1]</li>";
        }
        $errs .= "</ul>";
        $t->param( 'errs' => $errs );
    }
    #
    $self->print_html($t);
}

1;
