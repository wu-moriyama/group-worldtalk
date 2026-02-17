package FCC::View::Admin::CouaddfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;

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
        if ( $k =~ /^course_(step|status|group_upper|group_limit)$/ ) {
            $t->param( "${k}_${v}_selected" => "selected" );
        }
        elsif ( $k =~ /^course_(reco|group_flag|meeting_type)$/ ) {
            $t->param( "${k}_${v}_checked" => "checked" );
        }
        # ▼ ここから追加：weekday マスク
        elsif ( $k eq "course_weekday_mask" ) {
            my $mask = $v + 0;    # 数値化
            for my $w (0..6) {    # 0:日,1:月,2:火,3:水,4:木,5:金,6:土 の想定
                if ( $mask & (1 << $w) ) {
                    $t->param( "course_weekday_mask_${w}_checked" => "checked" );
                }
            }
        }
        # ▲ ここまで追加
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

    #講師情報
    my $prof = $context->{proc}->{prof};
    while ( my ( $k, $v ) = each %{$prof} ) {
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );
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
