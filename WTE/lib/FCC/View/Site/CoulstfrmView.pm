package FCC::View::Site::CoulstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Site::_SuperView);
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

    #会員ログイン済みなら会員メニューへリダイレクト
    if ( $context->{redirect} ) {
        my $url = $context->{redirect};
        print "Location: ${url}\n\n";
        return;
    }

    #テンプレートのロード
    my $t = $self->load_template();

    #検索結果の一覧
    my $epoch              = time;
    my $res                = $context->{res};
    my $course_intro_chars = $self->{tmpl_loop_params}->{list_loop}->{COURSE_INTRO_CHARS} + 0;
    unless ($course_intro_chars) { $course_intro_chars = 100; }
    my @list_loop;
    for my $ref ( @{ $res->{list} } ) {
        my %hash;
        while ( my ( $k, $v ) = each %{$ref} ) {
            $hash{$k} = CGI::Utils->new()->escapeHtml($v);
            if ( $k =~ /^course_(status|reco)$/ ) {
                $hash{"${k}_${v}"} = 1;
            }
            elsif ( $k =~ /^(course_fee)$/ ) {
                $hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
            }
            elsif ( $k eq "course_intro" ) {
                my $s = $v;
                $s =~ s/\x0D\x0A|\x0D|\x0A//g;
                $s =~ s/\s+/ /g;
                $s =~ s/^\s+//;
                $s =~ s/\s+$//;
                my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars( 0, $course_intro_chars );
                if ( $s ne $s2 ) { $s2 .= "…"; }
                $hash{$k} = CGI::Utils->new()->escapeHtml($s2);
            }
        }

        my $ccate_id_1 = $ref->{course_ccate_id_1};
        if ($ccate_id_1) {
            my $ccate_1 = $res->{ccates}->{$ccate_id_1};
            if ($ccate_1) {
                $hash{ccate_name_1} = CGI::Utils->new()->escapeHtml( $ccate_1->{ccate_name} );
            }
        }

        my $ccate_id_2 = $ref->{course_ccate_id_2};
        if ($ccate_id_2) {
            my $ccate_2 = $res->{ccates}->{$ccate_id_2};
            if ($ccate_2) {
                $hash{ccate_name_2} = CGI::Utils->new()->escapeHtml( $ccate_2->{ccate_name} );
            }
        }

        $hash{CGI_URL}    = $self->{conf}->{CGI_URL};
        $hash{static_url} = $self->{conf}->{static_url};
        $hash{epoch}      = $epoch;
        push( @list_loop, \%hash );
    }
    $t->param( "list_loop" => \@list_loop );

    #ページナビゲーション
    my @navi_params = ( 'hit', 'fetch', 'start', 'end', 'next_num', 'prev_num' );
    for my $k (@navi_params) {
        my $v = $res->{$k};
        $t->param( $k                => $v );
        $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
    }
    $t->param( "next_url" => $res->{next_url} );
    $t->param( "prev_url" => $res->{prev_url} );

    #ページナビゲーション
    $t->param( "page_loop" => $res->{page_list} );

    #検索条件
    while ( my ( $k, $v ) = each %{ $res->{params} } ) {
        if ( $k eq "sort_key" ) {
            $t->param( $k                   => $v );
            $t->param( "${k}_${v}_selected" => 'selected="selected"' );
        }
        elsif ( $k =~ /^(limit)$/ ) {
            $t->param( $k                   => $v );
            $t->param( "${k}_${v}_selected" => 'selected="selected"' );
        }
    }


    #カテゴリー選択
    my @s_ccate_1_loop;
    my @s_ccate_2_loop;
    for my $c1 ( @{ $res->{ccate_list} } ) {
        my $h1 = {};
        while ( my ( $k, $v ) = each %{$c1} ) {
            $h1->{$k} = CGI::Utils->new()->escapeHtml($v);
        }
        if ( $res->{params}->{course_ccate_id_1} == $c1->{ccate_id} ) {
            $h1->{selected} = "selected";
        }
        push( @s_ccate_1_loop, $h1 );
        for my $c2 ( @{ $c1->{children} } ) {
            my $h2 = {};
            while ( my ( $k, $v ) = each %{$c2} ) {
                $h2->{$k} = CGI::Utils->new()->escapeHtml($v);
            }
            if ( $res->{params}->{course_ccate_id_2} == $c2->{ccate_id} ) {
                $h2->{selected} = "selected";
            }
            push( @s_ccate_2_loop, $h2 );
        }
    }
    $t->param( "s_ccate_1_loop" => \@s_ccate_1_loop );
    $t->param( "s_ccate_2_loop" => \@s_ccate_2_loop );

    #検索対象のカテゴリー
    my $ccate_id_1 = $res->{params}->{course_ccate_id_1};
    if ($ccate_id_1) {
        my $ccate1 = $res->{ccates}->{$ccate_id_1};
        if ($ccate1) {
            $t->param( "ajax_ccate_name_1" => CGI::Utils->new()->escapeHtml( $ccate1->{ccate_name} ) );
        }
    }

    my $ccate_id_2 = $res->{params}->{course_ccate_id_2};
    if ($ccate_id_2) {
        my $ccate2 = $res->{ccates}->{$ccate_id_2};
        if ($ccate2) {
            $t->param( "ajax_ccate_name_2" => CGI::Utils->new()->escapeHtml( $ccate2->{ccate_name} ) );
        }
    }

    $t->param( "search_base_url" => $context->{search_base_url} );

    $self->print_html($t);
}

1;
