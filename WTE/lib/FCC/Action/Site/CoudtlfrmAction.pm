package FCC::Action::Site::CoudtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Site::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::Course;
use FCC::Class::Ccate;
use FCC::Class::Buzz; 

sub dispatch {
    my ($self) = @_;
    my $context = {};

    #授業識別IDを取得
    my $course_id = $self->{q}->param("course_id");
    unless ($course_id) {
        if ( $self->{conf}->{CGI_URL_PATH} =~ /\/coudtlfrm\/(\d+)/i ) {
            $course_id = $1;
        }
    }
    if ( !defined $course_id || $course_id eq "" || $course_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。(1)"];
        return $context;
    }

    #会員ログイン済みなら会員メニューへリダイレクト
    if ( $self->{session}->{data} && $self->{session}->{data}->{member_id} ) {
        $context->{redirect} = $self->{conf}->{ssl_host_url} . "/WTE/mypage.cgi?m=coudtlfrm&course_id=${course_id}";
        return $context;
    }

    #授業情報を取得
    my $ocourse = new FCC::Class::Course( conf => $self->{conf}, db => $self->{db} );
    my $course  = $ocourse->get($course_id);
    unless ($course) {
        $context->{fatalerrs} = ["不正なリクエストです。(2)"];
        return $context;
    }
    # 下書き(5)・承認待ち(6)は非公開（プレビュー時は担当講師のみ許可）
    my $is_preview = $self->{q}->param("preview") ? 1 : 0;
    my $preview_ok = 0;
    if ( $is_preview && $self->{session}->{data}->{prof}->{prof_id} ) {
        $preview_ok = ( $self->{session}->{data}->{prof}->{prof_id} == $course->{prof_id} ) ? 1 : 0;
    }
    if ( ( $course->{course_status} == 5 || $course->{course_status} == 6 ) && !$preview_ok ) {
        $context->{fatalerrs} = ["不正なリクエストです。(3)"];
        return $context;
    }
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
    for my $course ( @{ $course_res->{list} } ) {
        unless ( $course->{course_id} == $course_id ) {
            push( @{$course_list}, $course );
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
    $context->{preview}  = $preview_ok ? 1 : 0;

    $context->{course}      = $course;
    $context->{course_list} = $course_list;
    $context->{ccates}      = $ccates;
    return $context;
}

1;
