package FCC::View::Site::CoudtlfrmView;
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

    #授業情報
    my $course = $context->{course};
    while ( my ( $k, $v ) = each %{$course} ) {
        if ( !defined $v ) { $v = ""; }

        # ▼ まずはデフォルト（全部エスケープ）
        $t->param( $k => CGI::Utils->new()->escapeHtml($v) );

        # ▼ course_status / course_reco → フラグ
        if ( $k =~ /^course_(status|reco|meeting_type)$/ ) {
            $t->param( "${k}_${v}" => 1 );
        }
        # ▼ WYSIWYG の HTML はそのまま出す（★今回追加したいところ）
        elsif ( $k eq 'course_intro' || $k eq 'course_material' ) {
            # escapeHtml 済みの値を上書きして「生HTML」を渡す
            $t->param( $k => $v );
        }
        elsif ( $k eq 'prof_intro' ) {
            $t->param( $k => $v );  # escape しない
        }
        # ▼ 運営メモはテキスト＋改行 → <br>（従来どおり）
        elsif ( $k eq 'course_memo' ) {
            my $tmp = CGI::Utils->new()->escapeHtml($v);
            $tmp =~ s/\n/<br>/g;
            $t->param( $k => $tmp );
        }
        # ▼ ポイントはカンマ区切りもセット
        elsif ( $k =~ /^(course_fee|course_price)$/ ) {
            $t->param( "${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format() );
        }
        
        
    }

    # ▼ 日付フォーマット（YYYY-MM-DD → M月D日）
    my $start = $course->{course_start_date}; # 例: 2025-11-07
    my $end   = $course->{course_end_date};   # 例: 2026-01-09

    if ($start && $start =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
        my ($y, $m, $d) = ($1, $2, $3);
        $m =~ s/^0//; # 先頭ゼロ削除
        $d =~ s/^0//;
        $t->param( "course_start_date_fmt" => "${m}月${d}日" );
    }

    if ($end && $end =~ /^(\d{4})-(\d{2})-(\d{2})$/) {
        my ($y, $m, $d) = ($1, $2, $3);
        $m =~ s/^0//;
        $d =~ s/^0//;
        $t->param( "course_end_date_fmt" => "${m}月${d}日" );
    }

    # ▼ 時刻フォーマット（HH:MM:SS → HH:MM）
    my $time_s = $course->{course_time_start};
    my $time_e = $course->{course_time_end};

    if ($time_s && $time_s =~ /^(\d{2}):(\d{2}):\d{2}$/) {
        $t->param("course_time_start_fmt" => "$1:$2");
    }

    if ($time_e && $time_e =~ /^(\d{2}):(\d{2}):\d{2}$/) {
        $t->param("course_time_end_fmt" => "$1:$2");
    }

    # ▼ 曜日マスク（ビットフラグ）を日本語へ変換
    my $mask = $course->{course_weekday_mask};

    my %weekday_map = (
        1  => "日",
        2  => "月",
        4  => "火",
        8  => "水",
        16 => "木",
        32 => "金",
        64 => "土",
    );

    my @selected = ();

    for my $bit (sort {$a <=> $b} keys %weekday_map) {
        if ($mask & $bit) {
            push @selected, $weekday_map{$bit};
        }
    }

    # 「水・土」のように join
    if (@selected) {
        my $weekday_str = join("・", @selected);
        $t->param("course_weekday_fmt" => "毎週${weekday_str}曜");
    }


    #検索対象のカテゴリー
    my $ccate_id_1 = $course->{course_ccate_id_1};
    if ($ccate_id_1) {
        my $ccate1 = $context->{ccates}->{$ccate_id_1};
        if ($ccate1) {
            $t->param( "ccate_name_1" => CGI::Utils->new()->escapeHtml( $ccate1->{ccate_name} ) );
        }
    }

    my $ccate_id_2 = $course->{course_ccate_id_2};
    if ($ccate_id_2) {
        my $ccate2 = $context->{ccates}->{$ccate_id_2};
        if ($ccate2) {
            $t->param( "ccate_name_2" => CGI::Utils->new()->escapeHtml( $ccate2->{ccate_name} ) );
        }
    }

    #授業一覧
    my $course_intro_chars = $self->{tmpl_loop_params}->{course_loop}->{COURSE_INTRO_CHARS} + 0;
    unless ($course_intro_chars) { $course_intro_chars = 100; }
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
            #森山修正
            elsif ( $k =~ /^course_(status|reco|meeting_type)$/ ) {
                $hash{"${k}_${v}"} = 1;
            }
            elsif ( $k eq "course_intro" ) {
                my $s = $v;
                # ▼【追加】 HTMLタグをすべて削除する正規表現
                $s =~ s/<[^>]*>//g;
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

    # ▼ クチコミ（Buzz）をテンプレに渡す（追加）
    my $buz_num = scalar @{$context->{buz_list}};
    $t->param("buz_num" => $buz_num);

    my @buz_loop;
    for my $buz (@{$context->{buz_list}}) {
        my %h;
        while (my ($k, $v) = each %{$buz}) {
            $h{$k} = CGI::Utils->new()->escapeHtml($v);
        }
        push @buz_loop, \%h;
    }
    $t->param("buz_loop" => \@buz_loop);


    #
    $self->print_html($t);
}

1;
