package FCC::View::Admin::CoumodfrmView;
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

    #プリセット
    $t->param( "pkey" => $context->{proc}->{pkey} );
    my $in = $context->{proc}->{in};

    while ( my ( $k, $v ) = each %{$in} ) {
        if ( !defined $v ) { $v = ""; }
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
        if ( $k =~ /^course_(cdate|mdate)$/ ) {
            my @tm = FCC::Class::Date::Utils->new( time => $v, tz => $self->{conf}->{tz} )->get(1);
            for ( my $i = 0 ; $i <= 9 ; $i++ ) {
                $t->param( "${k}_${i}" => $tm[$i] );
            }
        }
        elsif ( $k =~ /^course_(step|status|group_upper|group_limit)$/ ) {
            $t->param( "${k}_${v}_selected" => "selected" );
        }
        elsif ( $k =~ /^course_(reco|group_flag|meeting_type)$/ ) {
            $t->param( "${k}_${v}_checked" => "checked" );
        }
        elsif ( $k eq 'course_weekday_mask' ) {
            my $mask = $v || 0;
            for my $bit ( 0 .. 6 ) {
                if ( $mask & ( 1 << $bit ) ) {
                    $t->param( "course_weekday_mask_${bit}_checked" => 'checked' );
                }
            }
        }
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

    #カテゴリー
    my @ccate_1_loop;
    my @ccate_2_loop;
    for my $c1 ( @{ $context->{ccate_list} } ) {
        my $h1 = {};
        while ( my ( $k, $v ) = each %{$c1} ) {
            $h1->{$k} = CGI::Utils->new()->escapeHtml($v);
        }
        if ( $in->{course_ccate_id_1} == $c1->{ccate_id} ) {
            $h1->{selected} = "selected";
        }
        push( @ccate_1_loop, $h1 );
        for my $c2 ( @{ $c1->{children} } ) {
            my $h2 = {};
            while ( my ( $k, $v ) = each %{$c2} ) {
                $h2->{$k} = CGI::Utils->new()->escapeHtml($v);
            }
            if ( $in->{course_ccate_id_2} == $c2->{ccate_id} ) {
                $h2->{selected} = "selected";
            }
            push( @ccate_2_loop, $h2 );
        }
    }
    $t->param( "ccate_1_loop" => \@ccate_1_loop );
    $t->param( "ccate_2_loop" => \@ccate_2_loop );

    #その他
    $t->param( "epoch" => time );
    for ( my $i = 1 ; $i <= 3 ; $i++ ) {
        $t->param( "prof_logo_${i}_w" => $self->{conf}->{"prof_logo_${i}_w"} );
        $t->param( "prof_logo_${i}_h" => $self->{conf}->{"prof_logo_${i}_h"} );
    }

    $self->print_html($t);
}

1;
