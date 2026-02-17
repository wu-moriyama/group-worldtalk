package FCC::View::Mypage::PrfdtlfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
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

    #講師情報
    while ( my ( $k, $v ) = each %{ $context->{prof} } ) {
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
        elsif ( $k eq "prof_fee" ) {
            $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
        }
    }

    #特徴/興味
    for my $k ( 'prof_character', 'prof_interest' ) {
        my $v    = $context->{prof}->{$k} + 0;
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

    #クチコミ
    my $buz_num = scalar @{ $context->{buz_list} };
    $t->param( "buz_num" => $buz_num );
    my @buz_loop;
    for my $buz ( @{ $context->{buz_list} } ) {
        my %h;
        while ( my ( $k, $v ) = each %{$buz} ) {
            $h{$k} = CGI::Utils->new()->escapeHtml($v);
        }
        push( @buz_loop, \%h );
    }
    $t->param( "buz_loop" => \@buz_loop );

    #授業一覧
    my $course_num = scalar @{ $context->{course_list} };
    $t->param( "course_num" => $course_num );
    my @course_loop;
    my $epoch = time;
    for my $ref ( @{ $context->{course_list} } ) {
        my %hash;
        while ( my ( $k, $v ) = each %{$ref} ) {
            $hash{$k} = CGI::Utils->new()->escapeHtml($v);
            if ( $k =~ /^(course_fee)$/ ) {
                $hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
            }
        }

        my $ccate_id_1 = $ref->{course_ccate_id_1};
        if ($ccate_id_1) {
            my $ccate_1 = $context->{ccates}->{$ccate_id_1};
            if ($ccate_1) {
                $hash{ccate_name_1} = CGI::Utils->new()->escapeHtml( $ccate_1->{ccate_name} );
            }
        }

        my $ccate_id_2 = $ref->{course_ccate_id_2};
        if ($ccate_id_2) {
            my $ccate_2 = $context->{ccates}->{$ccate_id_2};
            if ($ccate_2) {
                $hash{ccate_name_2} = CGI::Utils->new()->escapeHtml( $ccate_2->{ccate_name} );
            }
        }

        $hash{CGI_URL}    = $self->{conf}->{CGI_URL};
        $hash{static_url} = $self->{conf}->{static_url};
        $hash{epoch}      = $epoch;

        push( @course_loop, \%hash );
    }
    $t->param( "course_loop" => \@course_loop );

    #
    $self->print_html($t);
}

1;
