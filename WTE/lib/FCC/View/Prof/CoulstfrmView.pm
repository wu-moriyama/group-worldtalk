package FCC::View::Prof::CoulstfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);
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
            $hash{$k} = CGI::Utils->new()->escapeHtml($v);
            if ( $k =~ /^course_(status|reco|meeting_type)$/ ) {
                $hash{"${k}_${v}"} = 1;
            }
            # 料金（カンマ）
            if ( $k eq 'course_price' ) {
                $hash{"course_price_with_comma"} =
                    FCC::Class::String::Conv->new($v)->comma_format();
            }
            if ( $k =~ /^(course_fee)$/ ) {
                $hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
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



        # ▼ 曜日ラベル作成
        if (defined $ref->{course_weekday_mask}) {
            my @w = ('日','月','火','水','木','金','土');
            my @days;
            my $mask = $ref->{course_weekday_mask};

            for my $i (0..6) {
                push @days, $w[$i] if ($mask & (1 << $i));
            }

            if (@days) {
                $hash{course_weekday_label} = join('、', @days);
            } else {
                $hash{course_weekday_label} = "";   # ← ここが重要
            }
        }

        # ▼ 時刻の秒を消す
        for my $k2 ('course_time_start', 'course_time_end') {
            if (defined $ref->{$k2}) {
                my $v2 = $ref->{$k2};
                $v2 =~ s/:\d{2}$//; # 秒を削除
                $hash{$k2} = $v2;
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


    $self->print_html($t);
}

1;
