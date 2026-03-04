package FCC::Action::Admin::CoumodfrmtestmailAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Course;
use FCC::Class::Prof;
use FCC::Class::Member;
use FCC::Class::Tmpl;
use FCC::Class::Mail::Sendmail;
use FCC::Class::Date::Utils;

# テストメール送信（lsn9001/9002/9011/9012）
# 会員宛は member_id=9 固定、講師宛は prof_email。参照: WTE/cron/lesson_reminder.pl

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $course_id = $self->{q}->param("course_id");
    my $pkey     = $self->{q}->param("pkey");

    if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=coumodfrm&testmail_error=1" . ( $pkey ? "&pkey=${pkey}" : "" );
        return $context;
    }

    my $ocourse = FCC::Class::Course->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $course  = $ocourse->get($course_id);

    unless ($course) {
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=coumodfrm&testmail_error=1&course_id=${course_id}" . ( $pkey ? "&pkey=${pkey}" : "" );
        return $context;
    }

    # DB の course_mail_s / course_mail_e が入っていること
    my $mail_s_ok = $course->{course_mail_s} && $course->{course_mail_s} =~ /\S/;
    my $mail_e_ok = $course->{course_mail_e} && $course->{course_mail_e} =~ /\S/;

    unless ( $mail_s_ok && $mail_e_ok ) {
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=coumodfrm&testmail_error=notice&course_id=${course_id}" . ( $pkey ? "&pkey=${pkey}" : "" );
        return $context;
    }

    # 講師情報
    my $oprof = FCC::Class::Prof->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $prof  = $oprof->get( $course->{prof_id} );
    unless ($prof) {
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=coumodfrm&testmail_error=1&course_id=${course_id}" . ( $pkey ? "&pkey=${pkey}" : "" );
        return $context;
    }

    # 会員宛テスト送信用：member_id=9 の会員
    my $omember = FCC::Class::Member->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} );
    my $member  = $omember->get_from_db(9);
    unless ( $member && $member->{member_email} && $member->{member_email} =~ /\S/ ) {
        $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=coumodfrm&testmail_error=1&course_id=${course_id}" . ( $pkey ? "&pkey=${pkey}" : "" );
        return $context;
    }

    # 今の日時で lsn_stime / lsn_etime を生成（50分枠想定）
    my $now_epoch = time;
    my $step_min  = $course->{course_step} ? int( $course->{course_step} ) : 50;
    my $end_epoch = $now_epoch + ( $step_min * 60 );

    my $tz = $self->{conf}->{tz} || "Asia/Tokyo";
    my %stime_fmt = FCC::Class::Date::Utils->new( time => $now_epoch, tz => $tz )->get_formated();
    my %etime_fmt = FCC::Class::Date::Utils->new( time => $end_epoch, tz => $tz )->get_formated();

    my $lsn_stime = sprintf( "%s-%s-%s %s:%s:00", $stime_fmt{Y}, $stime_fmt{m}, $stime_fmt{d}, $stime_fmt{H}, $stime_fmt{i} );
    my $lsn_etime = sprintf( "%s-%s-%s %s:%s:00", $etime_fmt{Y}, $etime_fmt{m}, $etime_fmt{d}, $etime_fmt{H}, $etime_fmt{i} );

    my $stime = ( $stime_fmt{H} + 0 ) . ":" . $stime_fmt{i};
    my $etime = ( $etime_fmt{H} + 0 ) . ":" . $etime_fmt{i};

    # テンプレート用の ref（会員宛は member_id=9、講師宛は prof_email）
    my $c = $self->{conf};
    my $ref = {
        %{$course},
        %{$prof},
        lsn_stime     => $lsn_stime,
        lsn_etime     => $lsn_etime,
        stime         => $stime,
        etime         => $etime,
        member_handle => $member->{member_handle} || "テスト会員",
        member_email  => $member->{member_email},
        prof_email    => $prof->{prof_email},
    };

    while ( my ( $k, $v ) = each %stime_fmt ) {
        $ref->{"lsn_stime_${k}"} = $v;
    }
    while ( my ( $k, $v ) = each %etime_fmt ) {
        $ref->{"lsn_etime_${k}"} = $v;
    }

    my $ot = FCC::Class::Tmpl->new( conf => $c, db => $self->{db}, memd => $self->{memd} );

    # 開始通知(9001,9002)を先に送信し、続けて終了通知(9011,9012)を送る
    my @tmpl_ids = ( "lsn9001", "lsn9002", "lsn9011", "lsn9012" );
    for my $i ( 0 .. $#tmpl_ids ) {
        if ( $i == 2 ) {
            sleep 2;    # 開始通知の送信後に少し待ってから終了通知を送る
        }
        my $tmpl_id = $tmpl_ids[$i];
        my $t = $ot->get_template_object($tmpl_id);
        next unless $t;

        while ( my ( $k, $v ) = each %{$ref} ) {
            $t->param( $k => $v );
            $t->param( "${k}_${v}" => 1 ) if $k eq "lsn_pay_type";
        }
        $t->param( "ssl_host_url" => $c->{ssl_host_url} );
        $t->param( "sys_host_url" => $c->{sys_host_url} );
        $t->param( "pub_sender"   => $c->{pub_sender} );
        $t->param( "pub_from"     => $c->{pub_from} );
        $t->param( "product_name" => $c->{product_name} ) if $c->{product_name};
        $t->param( "member_caption" => $c->{member_caption} ) if $c->{member_caption};
        $t->param( "prof_caption"   => $c->{prof_caption} )   if $c->{prof_caption};

        my $eml = $t->output();
        next unless $eml;

        my $mail = FCC::Class::Mail::Sendmail->new(
            sendmail       => $c->{sendmail_path},
            smtp_host      => $c->{smtp_host},
            smtp_port      => $c->{smtp_port},
            smtp_auth_user => $c->{smtp_auth_user},
            smtp_auth_pass => $c->{smtp_auth_pass},
            smtp_timeout   => $c->{smtp_timeout},
            eml            => $eml,
            tz             => $tz
        );
        eval { $mail->mailsend(); };
    }

    $context->{redirect_url} = $self->{conf}->{CGI_URL} . "?m=coumodfrm&testmail_ok=1&course_id=${course_id}" . ( $pkey ? "&pkey=${pkey}" : "" );
    return $context;
}

1;
