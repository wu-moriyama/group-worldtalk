package FCC::Action::Admin::CouaddfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::Ccate;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "couadd" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("couadd");

        #講師識別IDを取得
        my $prof_id = $self->{q}->param("prof_id");
        if ( !defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }

        #講師情報を取得
        my $prof = FCC::Class::Prof->new(
            conf => $self->{conf},
            db   => $self->{db},
            memd => $self->{memd}
        )->get_from_db($prof_id);
        unless ($prof) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }
        $proc->{prof} = $prof;

        #初期値
        $proc->{in} = {
            prof_id             => $prof_id,
            course_status       => 0,
            course_order_weight => 0,
            course_reco         => 0,
            course_step         => 50,
            course_ccate_id_2   => 0,

            # ▼ ここから追加
            course_price        => "",
            course_start_date   => "",
            course_end_date     => "",
            course_weekday_mask => 0,
            course_time_start   => "",
            course_time_end     => "",
            course_material     => "",
            course_total_lessons => "",
            course_apply_deadline => "",
            course_holiday_dates => "",
            course_overview      => "",
            course_strength      => "",
            course_target        => "",
            course_effect        => "",
            course_message       => "",
            # ▲ ここまで追加
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
