package FCC::Action::Mypage::PrfschajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use Date::Pcalc;
use FCC::Class::Schedule;
use FCC::Class::Prof;
use FCC::Class::Course;
use FCC::Class::Date::Utils;

sub dispatch {
    my ($self)    = @_;
    my $context   = {};
    my $member_id = $self->{session}->{data}->{member}->{member_id};

    #講師識別IDを取得
    my $prof_id = $self->{q}->param("prof_id");
    if ( !defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。(11)"];
        return $context;
    }

    #講師情報を取得
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db} );
    my $prof  = $oprof->get_from_db($prof_id);
    if ( !$prof || !$prof->{prof_status} ) {
        $context->{fatalerrs} = ["不正なリクエストです。(12)"];
        return $context;
    }

    #授業識別IDを取得
    my $course_id = $self->{q}->param("course_id");
    if ($course_id) {
        if ( $prof_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。(13)"];
            return $context;
        }

        #授業識別IDをチェック
        my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
        my $course  = $ocourse->get($course_id);
        if ( !$course || !$course->{course_status} ) {
            $context->{fatalerrs} = ["不正なリクエストです。(14)"];
            return $context;
        }
        # 下書き(5)・承認待ち(6)は非公開
        if ( $course->{course_status} == 5 || $course->{course_status} == 6 ) {
            $context->{fatalerrs} = ["不正なリクエストです。(14)"];
            return $context;
        }
    }
    else {
        $course_id = "";
    }

    #指定年月を取得
    my $ym = $self->{q}->param("ym");

    #指定日を含む週の日付けリストを取得
    my $osch = new FCC::Class::Schedule( conf => $self->{conf}, db => $self->{db} );
    my $this_month_date_list;
    my @tm                   = FCC::Class::Date::Utils->new( time => time, tz => $self->{conf}->{tz} )->get(1);
    my $ym_s                 = "$tm[0]$tm[1]";
    my $available_datetime_e = $osch->get_available_datetime_e();
    my $ym_e                 = substr( $available_datetime_e, 0, 6 );
    if ($ym) {
        if ( $ym =~ /^(\d{4})(\d{2})$/ ) {
            my $y = $1;
            my $m = $2;
            if ( Date::Pcalc::check_date( $y, $m, 1 ) ) {
                if ( $ym lt $ym_s || $ym gt $ym_e ) {
                    $context->{fatalerrs} = ["不正なリクエストです。(1)"];
                    return $context;
                }
                $this_month_date_list = $osch->get_month_date_list( $y, $m );
            }
            else {
                $context->{fatalerrs} = ["不正なリクエストです。(2)"];
                return $context;
            }
        }
        else {
            $context->{fatalerrs} = ["不正なリクエストです。(3)"];
            return $context;
        }
    }
    else {
        $this_month_date_list = $osch->get_month_date_list_from_epoch(time);
    }
    my $dt = $this_month_date_list->[1]->[0];
    $ym = $dt->{Y} . $dt->{m};

    #登録済みのスケジュールを取得
    my $sd       = $this_month_date_list->[0]->[0];
    my $week_num = @{$this_month_date_list};
    my $ed       = $this_month_date_list->[ $week_num - 1 ]->[6];
    my $params   = {
        prof_id    => $prof_id,
        sch_date_s => $sd->{Y} . $sd->{m} . $sd->{d},
        sch_date_e => $ed->{Y} . $ed->{m} . $ed->{d},
        offset     => 0,
        limit      => 9999
    };
    my $res  = $osch->get_list($params);
    my $schs = {};
    for my $r ( @{ $res->{list} } ) {
		$r->{course_id} = $course_id;
        my ( $Y, $M, $D ) = $r->{sch_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})/;
        my $date = "${Y}${M}${D}";
        unless ( $schs->{$date} ) { $schs->{$date} = []; }
        push( @{ $schs->{$date} }, $r );
    }

    #先月の末日の日付情報
    my $last_month          = $osch->get_last_month_last_day_info( $dt->{Y}, $dt->{n} );
    my $last_month_ym       = $last_month->{Y} . $last_month->{m};
    my $last_month_disabled = "";
    if ( $last_month_ym lt $ym_s || $last_month_ym gt $ym_e ) {
        $last_month_disabled = "disabled";
    }

    #来月の1日の日付情報
    my $next_month          = $osch->get_next_month_first_day_info( $dt->{Y}, $dt->{n} );
    my $next_month_ym       = $next_month->{Y} . $next_month->{m};
    my $next_month_disabled = "";
    if ( $next_month_ym lt $ym_s || $next_month_ym gt $ym_e ) {
        $next_month_disabled = "disabled";
    }

    #今月のある日の情報（第二週目の日曜日）
    my $this_month = $this_month_date_list->[1]->[0];
    #
    $context->{this_month_date_list} = $this_month_date_list;
    $context->{last_month}           = $last_month;
    $context->{next_month}           = $next_month;
    $context->{this_month}           = $this_month;
    $context->{last_month_disabled}  = $last_month_disabled;
    $context->{next_month_disabled}  = $next_month_disabled;
    $context->{ym}                   = $ym;
    $context->{prof}                 = $prof;
    $context->{schs}                 = $schs;
    $context->{course_id}            = $course_id;
    return $context;
}

1;
