package FCC::Action::Prof::CoumodsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Course;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "coumod" );
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #入力値のname属性値のリスト
    my $in_names = [
        "course_status",
        "course_name",
        "course_copy",
        "course_fee",
        "course_price",
        "course_step",
        "course_ccate_id_1",
        "course_ccate_id_2",
        "course_logo",
        "course_youtube_id",
        "course_youtube_id_2",
        "course_intro",
        "course_mail_s",
        "course_mail_e",
        "course_meeting_url",
        "course_meeting_id",
        "course_meeting_pass",
        "course_meeting_type",
        "course_material",
        "course_total_lessons", 
        "course_start_date",
        "course_end_date",
        "course_weekday_mask",
        "course_logo_up",
        "course_logo_del",
        "course_group_flag",
        "course_group_upper",
        "course_group_limit",
        # ★ もし未追加なら、開始/終了時刻もここに追加
        "course_time_start",
        "course_time_end",
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

    if(!$proc->{in}->{course_group_flag}){
      $proc->{in}->{course_group_flag} = 0;
      $proc->{in}->{course_group_upper} = 0;
      $proc->{in}->{course_group_limit} = 0;
    }



# ▼ 時刻から course_step（分）を自動計算
if (
    defined $proc->{in}->{course_time_start} && $proc->{in}->{course_time_start} ne '' &&
    defined $proc->{in}->{course_time_end}   && $proc->{in}->{course_time_end}   ne ''
) {
    my $start = $proc->{in}->{course_time_start};
    my $end   = $proc->{in}->{course_time_end};

    # HH:MM or HH:MM:SS の両方を許容
    my ($sh, $sm) = $start =~ /^(\d{1,2}):(\d{2})(?::\d{2})?$/;
    my ($eh, $em) = $end   =~ /^(\d{1,2}):(\d{2})(?::\d{2})?$/;

    if ( defined $sh && defined $sm && defined $eh && defined $em ) {

        # 分に変換
        my $start_min = $sh * 60 + $sm;
        my $end_min   = $eh * 60 + $em;

        my $diff = $end_min - $start_min;

        # マイナスなら 1 にする
        if ( $diff <= 0 ) {
            $proc->{in}->{course_step} = 1;
        } else {
            $proc->{in}->{course_step} = $diff;
        }

    } else {
        # 時刻フォーマット不正 → デフォルト 1
        $proc->{in}->{course_step} = 1;
    }

} else {

    # 片方でも未入力 → デフォルト1
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
        my $course = $ocourse->mod( $proc->{in} );
        $proc->{course} = $course;
    }
    #
    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    return $context;
}

1;
