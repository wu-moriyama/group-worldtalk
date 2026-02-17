package FCC::Action::Mypage::LsnrsvcfmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Schedule;
use FCC::Class::Lesson;
use FCC::Class::Member;
use FCC::Class::Coupon;
use FCC::Class::Course;
use FCC::Class::Ccate;

sub dispatch {
    my ($self)    = @_;
    my $context   = {};
    my $member_id = $self->{session}->{data}->{member}->{member_id};

    $self->del_proc_session_data();
    my $proc = $self->create_proc_session_data("lsnrsv");
    $proc->{in} = {};

    my $olsn    = new FCC::Class::Lesson( conf => $self->{conf}, db => $self->{db} );
    my $osch    = new FCC::Class::Schedule( conf => $self->{conf}, db => $self->{db} );
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $omember = new FCC::Class::Member( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $ocoupon = new FCC::Class::Coupon( conf => $self->{conf}, db => $self->{db} );
    my $occate  = new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );

    #授業識別IDを取得
    my $selected_course_id = $self->{q}->param("course_id");
    if ($selected_course_id) {
        if ( $selected_course_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。(1)"];
            return $context;
        }
    }

    #スケジュール識別IDを取得
    my $sch_id = $self->{q}->param("sch_id");
    if ( !defined $sch_id || $sch_id eq "" || $sch_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。(2)"];
        return $context;
    }

    #最初のスケジュール枠の情報を取得
    my $sch = $osch->get($sch_id);
    if ( !$sch ) {
        $context->{fatalerrs} = ["不正なリクエストです。(3)"];
        return $context;
    }
    elsif ( $sch->{lsn_id} ) {
        $context->{fatalerrs} = ["先ほど予約の先着があったため、指定時間開始の授業は予約できません。"];
        return $context;
    }
    while ( my ( $k, $v ) = each %{$sch} ) {
        $proc->{in}->{$k} = $v;
    }
    my $prof_id   = $sch->{prof_id};
    my $prof_step = $sch->{prof_step};

    #授業一覧を取得
    my $course_res = $ocourse->get_list(
        {
            prof_id       => $prof_id,
            prof_status   => 1,
            course_status => 1,
            sort          => [ [ 'course_id', 'DESC' ] ],
            offset        => 0,
            limit         => 100
        }
    );
    my $course_list = $course_res->{list};
    unless ( @{$course_list} ) {
        $context->{fatalerrs} = ["サービス提供中の授業が見つかりませんでした。"];
        return $context;
    }

    #授業が事前選択された場合、該当の授業が存在するかをチェック
    my $selected_course;
    if ($selected_course_id) {
        for my $c ( @{$course_list} ) {
            if ( $c->{course_id} == $selected_course_id ) {
                $selected_course = $c;
                last;
            }
        }
        unless ($selected_course) {
            $context->{fatalerrs} = ["指定の授業が見つかりませんでした。"];
            return $context;
        }
    }

    #授業ごとに講師のスケジュールが空いているかをチェック
    my $pschs = {};
    for my $course ( @{$course_list} ) {

        #スケジュール枠の数を算出
        my $sch_num = $course->{course_step} / $prof_step;
        if ( $sch_num % 1 > 0 ) {
            $course->{is_prof_schedule_available} = 0;
            next;
        }

        #初回のスケジュール枠はチェック済みなので2つ目以降の枠をチェック
        $course->{is_prof_schedule_available} = 1;
        if ( $sch_num == 1 ) {
            next;
        }
        for ( my $i = 1 ; $i < $sch_num ; $i++ ) {
            my $stime_mins = ( $sch->{sch_stime_H} * 60 ) + $sch->{sch_stime_i} + ( $prof_step * $i );
            my $hour       = sprintf( "%02d", int( $stime_mins / 60 ) );
            my $min        = sprintf( "%02d", $stime_mins % 60 );
            my $stime      = $sch->{sch_stime_Y} . $sch->{sch_stime_m} . $sch->{sch_stime_d} . $hour . $min;
            my $schedule   = $osch->get_from_stime( $prof_id, $stime );
            if ( !$schedule || $schedule->{lsn_id} ) {
                $course->{is_prof_schedule_available} = 0;
                last;
            }
        }
    }

    #同じ時間に会員側の予約が重複していないかを授業ごとに確認
    #ついでに授業の開始時間と終了時間をセット
    for my $course ( @{$course_list} ) {
        my $stime_mins = $sch->{sch_stime_H} * 60 + $sch->{sch_stime_i};
        #my $etime_mins = $stime_mins + $course->{course_step};
        my $etime_mins = ($stime_mins + $course->{course_step}) % (24 * 60);
        my $etime_hour = sprintf( "%02d", int( $etime_mins / 60 ) );
        my $etime_min  = sprintf( "%02d", $etime_mins % 60 );
        my $stime      = $sch->{sch_stime_Y} . $sch->{sch_stime_m} . $sch->{sch_stime_d} . $sch->{sch_stime_H} . $sch->{sch_stime_i};
        my $etime      = $sch->{sch_etime_Y} . $sch->{sch_etime_m} . $sch->{sch_etime_d} . $etime_hour . $etime_min;
        if ( $olsn->is_double_booking( $member_id, $stime, $etime ) ) {
            $course->{is_double_booking} = 1;
        }
        else {
            $course->{is_double_booking} = 0;
        }

        $course->{course_stime_Gi} = $sch->{sch_stime_G} . ":" . $sch->{sch_stime_i};
        $course->{course_etime_Gi} = ($etime_hour + 0) . ":" . $etime_min;
    }


    #ポイントとクーポンの残高を確かめる
    my $member = $omember->get_from_db($member_id);

    $proc->{in}->{member_point}             = $member->{member_point};                                               # 保持ポイント
    $proc->{in}->{member_receivable_point}  = $olsn->get_receivable( $member_id, 1 );                                # ポイントの売り掛け
    $proc->{in}->{member_available_point}   = $member->{member_point} - $proc->{in}->{member_receivable_point};      # 実質的に利用可能なポイント
    $proc->{in}->{member_coupon}            = $member->{member_coupon};                                              # 保持クーポン
    $proc->{in}->{member_receivable_coupon} = $olsn->get_receivable( $member_id, 2 );                                # クーポンの売り掛け
    $proc->{in}->{member_available_coupon}  = $member->{member_coupon} - $proc->{in}->{member_receivable_coupon};    # 実質的に利用可能なクーポン

    #授業ごとに会員のポイントとクーポンの残高を確かめる
    $proc->{in}->{member_can_buy_by_point}  = 0;
    $proc->{in}->{member_can_buy_by_coupon} = 0;
    for my $course ( @{$course_list} ) {
        if ( $proc->{in}->{member_available_point} >= $course->{course_fee} ) {
            $course->{member_can_buy_by_point} = 1;
            $proc->{in}->{member_can_buy_by_point} = 1;
        }
        if ( $proc->{in}->{member_available_coupon} >= $course->{course_fee} && $sch->{prof_coupon_ok} ) {
            $course->{member_can_buy_by_coupon} = 1;
            $proc->{in}->{member_can_buy_by_coupon} = 1;
        }
    }

    #以上のチェックにより会員が授業を購入できるのかを総合チェック
    $proc->{in}->{member_can_buy} = 0;
    my $courses = {};
    for my $course ( @{$course_list} ) {
        my $can_buy = 0;
        if ( $course->{member_can_buy_by_point} || $course->{member_can_buy_by_coupon} ) {
            $can_buy = 1;
        }

        $course->{member_can_buy} = 0;
        if ( $can_buy == 1 && $course->{is_double_booking} == 0 && $course->{is_prof_schedule_available} == 1 ) {
            $course->{member_can_buy} = 1;
            $proc->{in}->{member_can_buy} = 1;
        }

        #購入不可の理由をセット
        my $reason = 0;
        if ( $course->{member_can_buy} == 0 ) {
            if ( $can_buy == 0 ) {
                $reason = 1;    #ポイントまたはクーポン残高不足
            }
            elsif ( $course->{is_double_booking} == 1 ) {
                $reason = 2;    #会員自身に予約時間の重複がある
            }
            elsif ( $course->{is_prof_schedule_available} == 0 ) {
                $reason = 3;    #講師のスケジュール枠がない、または埋まっている
            }
            else {
                $reason = 9;    #不明（これに該当することはないはず）
            }
        }
        $course->{"member_can_not_buy_reason"}           = $reason;
        $course->{"member_can_not_buy_reason_${reason}"} = 1;

        $courses->{ $course->{course_id} } = $course;
    }

    #授業が事前選択されていた場合、該当の授業が購入不可ならエラー
    #if ($selected_course) {
    #    unless ( $selected_course->{member_can_buy} ) {
    #        $context->{fatalerrs} = ["指定の授業を予約することができません。"];
    #        return $context;
    #    }
    #}

    #ポイントの有効期限をチェック
    if ( $proc->{in}->{member_can_buy_by_point} ) {
        if ( "$sch->{sch_stime_Y}-$sch->{sch_stime_m}-$sch->{sch_stime_d}" gt $member->{member_point_expire} ) {
            if ( $proc->{in}->{member_can_buy_by_coupon} ) {
                $proc->{in}->{member_can_buy_by_point} = 0;
            }
            else {
                my ( $y, $m, $d ) = split( /\-/, $member->{member_point_expire} );
                $y += 0;
                $m += 0;
                $d += 0;
                $context->{fatalerrs} = ["ポイントの有効期限を過ぎた予約はできません。（あなたのポイント有効期限は${y}年${m}月${d}日です）"];
                return $context;
            }
        }
    }

    #クーポンの有効期限をチェック
    if ( $proc->{in}->{member_can_buy_by_coupon} ) {
        my $coupon = $ocoupon->get( $member->{coupon_id} );
        if ( "$sch->{sch_stime_Y}-$sch->{sch_stime_m}-$sch->{sch_stime_d}" gt $coupon->{coupon_expire} ) {
            if ( $proc->{in}->{member_can_buy_by_point} ) {
                $proc->{in}->{member_can_buy_by_coupon} = 0;
            }
            else {
                my ( $y, $m, $d ) = split( /\-/, $coupon->{coupon_expire} );
                $y += 0;
                $m += 0;
                $d += 0;
                $context->{fatalerrs} = ["クーポンの有効期限を過ぎた予約はできません。（あなたのクーポン有効期限は${y}年${m}月${d}日です）"];
                return $context;
            }
        }
    }

    #カテゴリー取得
    my $ccates = $occate->get_all();

    $self->set_proc_session_data($proc);
    $context->{proc}            = $proc;
    $context->{course_list}     = $course_list;
    $context->{ccates}          = $ccates;
    $context->{selected_course} = $selected_course;
    return $context;
}

1;
