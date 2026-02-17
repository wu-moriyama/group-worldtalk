package FCC::View::Admin::CoulstfrmView;
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

    #検索結果の一覧
    my $res = $context->{res};
    my @list_loop;
    my $epoch = time;
    for my $ref ( @{ $res->{list} } ) {
        my %hash;

        while ( my ( $k, $v ) = each %{$ref} ) {

            # まず表示用の値を out_v にコピー
            my $out_v = $v;

            # ▼ 時刻（hh:mm:ss → hh:mm に整形：秒が00のとき）
            if ( defined $out_v && $out_v ne '' && $k =~ /^course_time_(start|end)$/ ) {
                # 例）20:00:00 → 20:00, 20:50:00 → 20:50
                $out_v =~ s/:(\d{2}):00$/:$1/;
            }

            # HTMLエスケープしてテンプレ用ハッシュに格納
            $hash{$k} = CGI::Utils->new()->escapeHtml($out_v);

            # ステータス・おすすめフラグ用
            if ( $k =~ /^course_(status|reco|meeting_type)$/ ) {
                $hash{"${k}_${v}"} = 1;
            }
            # 金額系（カンマ付き）
            elsif ( $k =~ /^(course_fee|course_price)$/ ) {
                $hash{"${k}_with_comma"} =
                    FCC::Class::String::Conv->new($v)->comma_format();
            }
        }

        # ▼ 開催曜日マスク（例：20 → 「火、木」） → course_weekday_label にセット
        if ( defined $ref->{course_weekday_mask} && $ref->{course_weekday_mask} ne '' ) {
            my $mask = $ref->{course_weekday_mask};
            my @wd_kanji = ('日','月','火','水','木','金','土');
            my @names;

            for my $i (0..6) {
                my $bit = 1 << $i;   # 1, 2, 4, 8, 16, 32, 64
                if ( $mask & $bit ) {
                    push @names, $wd_kanji[$i];
                }
            }

            if (@names) {
                my $label = join('、', @names);   # 例: 火、木
                $hash{course_weekday_label} = CGI::Utils->new()->escapeHtml($label);
            }
        }

        # ▼ カテゴリー名などはそのまま
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
        if ( $k =~ /^course_status$/ ) {
            $t->param( "s_${k}_${v}_selected" => 'selected' );
            $t->param( "s_${k}_${v}"          => 1 );
            if ( $v ne "" ) {
                $t->param( "s_${k}_selected" => 1 );
            }
        }
        elsif ( $k =~ /^(limit)$/ ) {
            $t->param( $k                   => $v );
            $t->param( "${k}_${v}_selected" => 'selected' );
        }
        else {
            $t->param( "s_${k}" => CGI::Utils->new()->escapeHtml($v) );
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
        if ( defined($res->{params}->{course_ccate_id_1}) && $res->{params}->{course_ccate_id_1} == $c1->{ccate_id} ) {
            $h1->{selected} = "selected";
        }
        push( @s_ccate_1_loop, $h1 );
        for my $c2 ( @{ $c1->{children} } ) {
            my $h2 = {};
            while ( my ( $k, $v ) = each %{$c2} ) {
                $h2->{$k} = CGI::Utils->new()->escapeHtml($v);
            }
            if ( defined($res->{params}->{course_ccate_id_2}) && $res->{params}->{course_ccate_id_2} == $c2->{ccate_id} ) {
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

    #検索対象の授業情報
    if ( defined $res->{course} && ref( $res->{course} ) eq "HASH" ) {
        while ( my ( $k, $v ) = each %{ $res->{course} } ) {
            $t->param( "ajax_${k}" => CGI::Utils->new()->escapeHtml($v) );
        }
    }

    #検索対象の講師情報
    if ( defined $res->{prof} && ref( $res->{prof} ) eq "HASH" ) {
        while ( my ( $k, $v ) = each %{ $res->{prof} } ) {
            $t->param( "ajax_${k}" => CGI::Utils->new()->escapeHtml($v) );
        }
    }

    #CSVダウンロードURL
    $t->param( "download_url" => $res->{download_url} );
    #
    $self->print_html($t);
}

1;
