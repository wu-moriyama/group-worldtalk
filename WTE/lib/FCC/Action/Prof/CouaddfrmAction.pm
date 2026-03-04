package FCC::Action::Prof::CouaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Ccate;

sub dispatch {
    my ($self)  = @_;
    my $context = {};
    my $prof_id = $self->{session}->{data}->{prof}->{prof_id};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "couadd" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("couadd");

        # 編集フォーム（Coumodfrm）と同じ項目で初期値のみ未入力
        $proc->{in} = {
            prof_id              => $prof_id,
            course_status        => 5,      # 下書き
            course_order_weight  => 0,
            course_reco          => 0,
            course_name          => '',
            course_copy          => '',
            course_fee           => 1,
            course_price         => '',
            course_step         => 50,
            course_ccate_id_1    => '',
            course_ccate_id_2    => '',
            course_intro         => '',
            course_material      => '',
            course_material_drive_url => '',
            course_youtube_id    => '',
            course_youtube_id_2  => '',
            course_overview      => '',
            course_strength      => '',
            course_target        => '',
            course_effect        => '',
            course_message       => '',
            course_mail_s        => '',
            course_mail_e        => '',
            course_start_date    => '',
            course_end_date      => '',
            course_weekday_mask  => 0,
            course_time_start    => '',
            course_time_end      => '',
            course_meeting_type  => 1,
            course_meeting_url   => '',
            course_meeting_id    => '',
            course_meeting_pass  => '',
            course_group_flag    => 1,
            course_group_upper   => 10,
            course_group_limit   => 2,
            course_total_lessons => 1,
            course_apply_deadline => '',
            course_holiday_dates => '',
        };

        $self->set_proc_session_data($proc);
    }

    #カテゴリー取得
    my $occate =
      new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    $context->{ccate_list} = $occate->get_children( { ccate_status => 1 } );
    #
    $context->{proc} = $proc;
    return $context;
}

1;
