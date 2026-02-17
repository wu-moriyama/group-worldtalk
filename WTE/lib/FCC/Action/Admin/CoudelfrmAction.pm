package FCC::Action::Admin::CoudelfrmAction;
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
    my $proc = $self->get_proc_session_data( $pkey, "coudel" );
    unless ($proc) {
        $proc = $self->create_proc_session_data("coudel");

        #識別IDを取得
        my $course_id = $self->{q}->param("course_id");
        if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }

        #インスタンス
        my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );

        #情報を取得
        my $course = $ocourse->get($course_id);
        unless ($course) {
            $context->{fatalerrs} = ["不正なリクエストです。"];
            return $context;
        }
        $proc->{course} = $course;
        #
        $self->set_proc_session_data($proc);
    }

    #カテゴリー取得
    my $occate = new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    $context->{ccates} = $occate->get_all();

    $context->{proc} = $proc;
    return $context;
}

1;
