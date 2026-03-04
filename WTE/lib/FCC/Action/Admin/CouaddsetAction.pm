package FCC::Action::Admin::CouaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Course;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "couadd" );
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #入力値のname属性値のリスト
    my $in_names = [
        # 既存項目
        "course_status",
        "course_name",
        "course_copy",
        "course_fee",
        "course_order_weight",
        "course_reco",
        "course_step",
        "course_ccate_id_1",
        "course_ccate_id_2",
        "course_logo",
        "course_youtube_id",
        "course_youtube_id_2",
        "course_intro",
        "course_overview",
        "course_strength",
        "course_target",
        "course_effect",
        "course_message",
        "course_mail_s",
        "course_mail_e",
        "course_meeting_url",
        "course_meeting_id",
        "course_meeting_pass",
        "course_meeting_type",
        "course_syllabus",
        "course_landingpage",
        "course_apply_form_url",
        "course_material_drive_url",
        "course_memo",
        "course_group_flag",
        "course_group_upper",
        "course_group_limit",
        "course_logo_up",
        "course_logo_del",

        # ▼ ここから新規追加項目
        "course_price",         # 講座価格
        "course_start_date",    # 講座開始日 (DATE)
        "course_end_date",      # 講座終了日 (DATE)
        "course_weekday_mask",  # 開催曜日ビットマスク (0〜127)
        "course_time_start",    # 開始時刻 (HH:MM / HH:MM:SS)
        "course_time_end",      # 終了時刻 (HH:MM / HH:MM:SS)
        "course_material",      # 使用教材
        "course_total_lessons",
        "course_apply_deadline",
        "course_holiday_dates",
        # ▲ ここまで新規追加項目
    ];

    #入力値を取得
    my $in = $self->get_input_data($in_names);
    while ( my ( $k, $v ) = each %{$in} ) {
        $proc->{in}->{$k} = $v;
    }

    # ▼ course_total_lessons が空ならデフォルト 1 をセット
    if (!defined $proc->{in}->{course_total_lessons} || $proc->{in}->{course_total_lessons} eq '') {
        $proc->{in}->{course_total_lessons} = 1;
    }

    # --------------------------------------------------
    # 開始時刻・終了時刻から course_step（分）を自動計算
    # --------------------------------------------------
    if ( $proc->{in}->{course_time_start} && $proc->{in}->{course_time_end} ) {

        my $start = $proc->{in}->{course_time_start};
        my $end   = $proc->{in}->{course_time_end};

        # フォーマット補正：HH:MM → HH:MM:SS にそろえる
        for my $key (qw/course_time_start course_time_end/) {
            my $t = $proc->{in}->{$key};
            if ( defined $t && $t ne '' ) {
                if ( $t =~ /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/ ) {
                    my ($h, $m, $s) = ($1, $2, defined $3 ? $3 : 0);
                    $proc->{in}->{$key} = sprintf("%02d:%02d:%02d", $h, $m, $s);
                }
            }
        }

        # 秒に変換して差分から分数を出す
        my ($sh, $sm, $ss) = split(/:/, $proc->{in}->{course_time_start});
        my ($eh, $em, $es) = split(/:/, $proc->{in}->{course_time_end});

        my $start_sec = $sh * 3600 + $sm * 60 + $ss;
        my $end_sec   = $eh * 3600 + $em * 60 + $es;

        # 終了 > 開始 のときだけ計算、それ以外は1をセット
        if ( $end_sec > $start_sec ) {
            my $diff_sec = $end_sec - $start_sec;
            my $minutes  = int( $diff_sec / 60 );
            $proc->{in}->{course_step} = $minutes;
        } else {
            $proc->{in}->{course_step} = 1;  # 不正時刻
        }

    } else {

        # 片方でも空 → デフォルト1
        $proc->{in}->{course_step} = 1;
    }



    # FCC:Class::Courseインスタンス
    my $ocourse = new FCC::Class::Course(
        conf => $self->{conf},
        db   => $self->{db},
        pkey => $pkey,
        q    => $self->{q}
    );

    #入力値チェック
    my @errs = $ocourse->input_check( $in_names, $proc->{in} );

    #エラーハンドリング
    if (@errs) {
        $proc->{errs} = \@errs;
    }
    else {
        $proc->{errs} = [];
        my $course = $ocourse->add( $proc->{in} );
        $proc->{course} = $course;
    }
    #
    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    return $context;
}

1;
