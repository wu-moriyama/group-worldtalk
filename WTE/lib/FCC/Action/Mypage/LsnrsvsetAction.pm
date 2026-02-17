package FCC::Action::Mypage::LsnrsvsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Schedule;
use FCC::Class::Lesson;
use FCC::Class::Course;
use FCC::Class::Member;
use FCC::Class::Coupon;
use FCC::Class::Mail::Sendmail;
use FCC::Class::String::Conv;
use FCC::Class::Tmpl;
use Date::Pcalc;

sub dispatch {
    my ($self)    = @_;
    my $context   = {};
    my $member_id = $self->{session}->{data}->{member}->{member_id};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "lsnrsv" );
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。(1)"];
        return $context;
    }

    my $osch    = new FCC::Class::Schedule( conf => $self->{conf}, db => $self->{db} );
    my $olsn    = new FCC::Class::Lesson( conf => $self->{conf}, db => $self->{db} );
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $omember = new FCC::Class::Member( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $ocoupon = new FCC::Class::Coupon( conf => $self->{conf}, db => $self->{db} );

    #授業識別IDを取得
    my $course_id = $self->{q}->param("course_id");
    if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["授業を選択してください。"];
        return $context;
    }

    #授業情報を取得
    my $course = $ocourse->get($course_id);
    if ( !$course ) {
        $context->{fatalerrs} = ["不正なリクエストです。(2)"];
        return $context;
    }

    #スケジュール識別IDを取得
    my $sch_id = $self->{q}->param("sch_id");
    if ( !defined $sch_id || $sch_id eq "" || $sch_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。(3)"];
        return $context;
    }

    #最初のスケジュール情報を取得
    my $sch = $osch->get($sch_id);
    if ( !$sch ) {
        $context->{fatalerrs} = ["不正なリクエストです。(4)"];
        return $context;
    }
    elsif ( $sch->{lsn_id} ) {
        $context->{fatalerrs} = ["先ほど予約の先着があったため、指定時間開始の授業は予約できません。"];
        return $context;
    }
    my $prof_id   = $sch->{prof_id};
    my $prof_step = $sch->{prof_step};

    #スケジュール予約期限チェック
    if ( $sch->{disabled} ) {
        $context->{fatalerrs} = ["予約期限が過ぎたため、このレッスンは予約できません。"];
        return $context;
    }

    #スケジュール枠の数を算出
    my $sch_num = $course->{course_step} / $prof_step;
    if ( $sch_num % 1 > 0 ) {
        $context->{fatalerrs} = [ $self->{prof_caption} . "の単位時間と授業の単位時間に不一致が見つかりました。" ];
        return $context;
    }

    #講師のスケジュールが空いているかをチェック
    #初回のスケジュール枠はチェック済みなので2つ目以降の枠をチェック
    my @sch_id_list = ( $sch->{sch_id} );
    if ( $sch_num > 1 ) {
        my $is_prof_schedule_available = 1;
        for ( my $i = 1 ; $i < $sch_num ; $i++ ) {
            my $stime_mins = ( $sch->{sch_stime_H} * 60 ) + $sch->{sch_stime_i} + ( $prof_step * $i );
            my $hour       = sprintf( "%02d", int( $stime_mins / 60 ) );
            my $min        = sprintf( "%02d", $stime_mins % 60 );
            my $stime      = $sch->{sch_stime_Y} . $sch->{sch_stime_m} . $sch->{sch_stime_d} . $hour . $min;
            my $schedule   = $osch->get_from_stime( $prof_id, $stime );
            if ( !$schedule || $schedule->{lsn_id} ) {
                $is_prof_schedule_available = 0;
                last;
            }
            push( @sch_id_list, $schedule->{sch_id} );
        }
        unless ($is_prof_schedule_available) {
            $context->{fatalerrs} = [ $self->{prof_caption} . "のスケジュールが空いていません。" ];
            return $context;
        }
    }

    #同じ時間に会員側の予約が重複していないかを授業ごとに確認
    my $course_stime = $sch->{sch_stime};
    my $course_etime = '';
    {
        my $stime_mins = $sch->{sch_stime_H} * 60 + $sch->{sch_stime_i};
        my $etime_mins = $stime_mins + $course->{course_step};

        if ( $etime_mins > 60 * 24 ) {
            $context->{fatalerrs} = ["日をまたいで予約することはできません。"];
            return $context;
        }

        my $stime = $sch->{sch_stime_Y} . $sch->{sch_stime_m} . $sch->{sch_stime_d} . $sch->{sch_stime_H} . $sch->{sch_stime_i};

        my $etime = '';

        if ( $etime_mins == 60 * 24 ) {
            #my($nY, $nM, $nD) = Date::Pcalc::Add_Delta_Days($sch->{sch_etime_Y}, $sch->{sch_etime_m}, $sch->{sch_etime_d}, 1);
            my($nY, $nM, $nD) = Date::Pcalc::Add_Delta_Days($sch->{sch_stime_Y}, $sch->{sch_stime_m}, $sch->{sch_stime_d}, 1);
            $nM = sprintf("%02d", $nM);
            $nD = sprintf("%02d", $nD);
            $etime = $nY . $nM . $nD . '0000';
            $course_etime = $nY . '-' . $nM . '-' . $nD . ' 00:00';
        }
        else {
            my $etime_hour = sprintf( "%02d", int( $etime_mins / 60 ) );
            my $etime_min  = sprintf( "%02d", $etime_mins % 60 );
            $etime = $sch->{sch_etime_Y} . $sch->{sch_etime_m} . $sch->{sch_etime_d} . $etime_hour . $etime_min;
            $course_etime = $sch->{sch_etime_Y} . '-' . $sch->{sch_etime_m} . '-' . $sch->{sch_etime_d} . ' ' . $etime_hour . ':' . $etime_min;
        }

        if ( $olsn->is_double_booking( $member_id, $stime, $etime ) ) {
            $context->{fatalerrs} = ["すでに同時刻に別の予約が入っています。"];
            return $context;
        }

    }

    #支払種別
    my $lsn_pay_type = $self->{q}->param("lsn_pay_type");
    if ($lsn_pay_type) {
        if ( $lsn_pay_type !~ /^(1|2)$/ ) {
            $context->{fatalerrs} = ["パラメータエラー"];
            return $context;
        }
    }
    else {
        $lsn_pay_type = 1;
    }

    #ポイントとクーポンの残高を確かめる
    my $member = $omember->get_from_db($member_id);
    if ( $lsn_pay_type == 1 ) {    #ポイントの場合
        my $receivable_point = $olsn->get_receivable( $member_id, 1 );         # ポイントの売り掛け
        my $available_point  = $member->{member_point} - $receivable_point;    # 実質的に利用可能なポイント
        if ( $available_point < $course->{course_fee} ) {
            $context->{fatalerrs} = ["ポイント残高が不足しています。"];
            return $context;
        }

        #ポイントの有効期限をチェック
        if ( "$sch->{sch_stime_Y}-$sch->{sch_stime_m}-$sch->{sch_stime_d}" gt $member->{member_point_expire} ) {
            my ( $y, $m, $d ) = split( /\-/, $member->{member_point_expire} );
            $y += 0;
            $m += 0;
            $d += 0;
            $context->{fatalerrs} = ["ポイントの有効期限を過ぎた予約はできません。（あなたのポイント有効期限は${y}年${m}月${d}日です）"];
            return $context;
        }

    }
    else {    #クーポンの場合
        my $receivable_coupon = $olsn->get_receivable( $member_id, 2 );           # クーポンの売り掛け
        my $available_coupon  = $member->{member_coupon} - $receivable_coupon;    # 実質的に利用可能なクーポン
        if ( $available_coupon < $course->{course_fee} ) {
            $context->{fatalerrs} = ["クーポン残高が不足しています。"];
            return $context;
        }

        #クーポンの有効期限をチェック
        my $coupon = $ocoupon->get( $member->{coupon_id} );
        if ( "$sch->{sch_stime_Y}-$sch->{sch_stime_m}-$sch->{sch_stime_d}" gt $coupon->{coupon_expire} ) {
            my ( $y, $m, $d ) = split( /\-/, $coupon->{coupon_expire} );
            $y += 0;
            $m += 0;
            $d += 0;
            $context->{fatalerrs} = ["クーポンの有効期限を過ぎた予約はできません。（あなたのクーポン有効期限は${y}年${m}月${d}日です）"];
            return $context;
        }
    }

    #予約処理
    my $lsn = $olsn->add(
        {
            prof_id      => $sch->{prof_id},
            member_id    => $member_id,
            seller_id    => $member->{seller_id},
            course_id    => $course_id,
            lsn_stime    => $course_stime,
            lsn_etime    => $course_etime,
            lsn_prof_fee => $course->{course_fee},
            lsn_pay_type => $lsn_pay_type,
            coupon_id    => $member->{coupon_id} ? $member->{coupon_id} : 0
        },
        \@sch_id_list
    );

    while ( my ( $k, $v ) = each %{$lsn} ) {
        $proc->{in}->{$k} = $v;
    }

    #通知メール送信
    my $ml_data = {};
    while ( my ( $k, $v ) = each %{$lsn} ) {
        $ml_data->{$k} = $v;
    }
    while ( my ( $k, $v ) = each %{ $self->{session}->{data}->{member} } ) {
        $ml_data->{$k} = $v;
    }
    $self->send_mail($ml_data);
    #
    $context->{proc} = $proc;

    $self->set_proc_session_data($proc);
    return $context;
}

sub send_mail {
    my ( $self, $in ) = @_;
    unless ( $in->{member_email} ) { return; }
    my $ot = new FCC::Class::Tmpl( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    for my $tmpl_id ( "rsv9001", "rsv9002" ) {
        my $t = $ot->get_template_object($tmpl_id);

        #置換
        while ( my ( $k, $v ) = each %{$in} ) {
            $t->param( $k => $v );
            if ( $k eq "lsn_pay_type" ) {
                $t->param( "${k}_${v}" => 1 );
            }
        }
        $t->param( "ssl_host_url" => $self->{conf}->{ssl_host_url} );
        $t->param( "sys_host_url" => $self->{conf}->{sys_host_url} );
        $t->param( "pub_sender"   => $self->{conf}->{pub_sender} );
        $t->param( "pub_from"     => $self->{conf}->{pub_from} );

        #ヘッダーとボディー
        my $eml  = $t->output();
        my $mail = new FCC::Class::Mail::Sendmail(
            sendmail       => $self->{conf}->{sendmail_path},
            smtp_host      => $self->{conf}->{smtp_host},
            smtp_port      => $self->{conf}->{smtp_port},
            smtp_auth_user => $self->{conf}->{smtp_auth_user},
            smtp_auth_pass => $self->{conf}->{smtp_auth_pass},
            smtp_timeout   => $self->{conf}->{smtp_timeout},
            eml            => $eml,
            tz             => $self->{conf}->{tz}
        );
        $mail->mailsend();
        if ( my $error = $mail->error() ) {
            die $error;
        }
    }
}

1;
