package FCC::Action::Admin::CoumodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Course;
use FCC::Class::Ccate;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #プロセスセッション
    my $pkey = $self->{q}->param("pkey");
    my $proc = $self->get_proc_session_data( $pkey, "coumod" );

    my $ocourse = new FCC::Class::Course(
        conf => $self->{conf},
        db   => $self->{db},
        memd => $self->{memd}
    );

    if ($proc) {
        if ( $proc->{in}->{course_logo_updated} != 1 ) {
            if ( $proc->{in}->{course_logo_up} || $proc->{in}->{course_logo_del} eq "1" ) {
                $proc->{in}->{course_logo_updated} = 1;
            }
            else {
                #情報を取得
                my $ocourse_orig = $ocourse->get( $proc->{in}->{course_id} );

                #オリジナルのocourse_logoをセット
                $proc->{in}->{course_logo} = $ocourse_orig->{course_logo};
            }
        }
    }
    else {
        my $course_id = $self->{q}->param("course_id");
        if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }
        $proc = $self->create_proc_session_data("coumod");

        #情報を取得
        my $course = $ocourse->get($course_id);
        unless ($course) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }
        $proc->{in} = $course;
        $proc->{in}->{course_logo_updated} = 0;
        #
        $self->set_proc_session_data($proc);
    }

    #カテゴリー取得
    my $occate =
      new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    $context->{ccate_list} = $occate->get_children( { ccate_status => 1 } );

    $context->{proc} = $proc;
    return $context;
}

1;
