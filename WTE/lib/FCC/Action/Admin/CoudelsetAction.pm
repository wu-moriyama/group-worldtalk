package FCC::Action::Admin::CoudelsetAction;
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
    my $proc = $self->get_proc_session_data( $pkey, "coudel" );
    if ( !$proc ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    # FCC:Class::Courseインスタンス
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );

    #削除対象の識別ID
    my $course_id = $proc->{course}->{course_id};
    if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #削除処理
    $proc->{errs} = [];
    my $course = $ocourse->del($course_id);
    unless ($course) {
        $context->{fatalerrs} = ["対象のレコードは登録されておりません。: course_id=${course_id}"];
        return $context;
    }
    #
    $self->set_proc_session_data($proc);
    $context->{proc} = $proc;
    return $context;
}

1;
