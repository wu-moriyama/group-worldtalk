package FCC::Action::Mypage::CoudtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::Course;
use FCC::Class::Ccate;
use FCC::Class::Buzz; 

sub dispatch {
    my ($self)    = @_;
    my $context   = {};
    my $member_id = $self->{session}->{data}->{member}->{member_id};

    #授業識別IDを取得
    my $course_id = $self->{q}->param("course_id");
    if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。(1)"];
        return $context;
    }

    #授業情報を取得
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $course  = $ocourse->get($course_id);
    unless ($course) {
        $context->{fatalerrs} = ["不正なリクエストです。(2)"];
        return $context;
    }
    #if ( $course->{course_status} < 1 ) {
    #    $context->{fatalerrs} = ["不正なリクエストです。(3)"];
    #    return $context;
    #}
    unless ( $course->{prof_status} == 1 ) {
        $context->{fatalerrs} = ["不正なリクエストです。(4)"];
        return $context;
    }

    my $prof_id = $course->{prof_id};

    #授業一覧を取得
    my $ocourse    = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $course_res = $ocourse->get_list(
        {
            prof_id       => $prof_id,
            course_status => 1,
            sort          => [ [ 'course_id', 'DESC' ] ],
            offset        => 0,
            limit         => 100
        }
    );
    #自分自身を除外
    my $course_list = [];
    for my $course (@{$course_res->{list}}) {
        unless($course->{course_id} == $course_id) {
            push(@{$course_list}, $course);
        }
    }

    #カテゴリー取得
    my $occate = new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    my $ccates = $occate->get_all();

    # ▼ クチコミを取得（追加）
    my $obuz = new FCC::Class::Buzz(conf=>$self->{conf}, db=>$self->{db});
    my $buz_res = $obuz->get_list({
        prof_id => $prof_id,
        buz_show => 1,
        offset => 0,
        limit => 100,
        sort   => [["buz_id", "DESC"]]
    });
    my $buz_list = $buz_res->{list};
    # ▼ context にセット
    $context->{buz_list} = $buz_list;

    $context->{course}      = $course;
    $context->{course_list} = $course_list;
    $context->{ccates}      = $ccates;
    return $context;
}

1;
