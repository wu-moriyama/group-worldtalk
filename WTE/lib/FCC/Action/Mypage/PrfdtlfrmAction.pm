package FCC::Action::Mypage::PrfdtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::Fav;
use FCC::Class::Buzz;
use FCC::Class::Course;
use FCC::Class::Ccate;

sub dispatch {
    my ($self)    = @_;
    my $context   = {};
    my $member_id = $self->{session}->{data}->{member}->{member_id};

    #講師識別IDを取得
    my $prof_id = $self->{q}->param("prof_id");
    if ( !defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #講師情報を取得
    my $oprof = new FCC::Class::Prof( conf => $self->{conf}, db => $self->{db} );
    my $prof  = $oprof->get_from_db($prof_id);
    if ( !$prof || $prof->{prof_status} != 1 ) {
        $context->{fatalerrs} = ["不正なリクエストです。"];
        return $context;
    }

    #お気に入り
    my $ofav = new FCC::Class::Fav( conf => $self->{conf}, db => $self->{db} );
    my $fav  = $ofav->get_from_member_prof_id( $member_id, $prof->{prof_id} );
    if ($fav) {
        $prof->{is_fav} = 1;
    }
    else {
        $prof->{is_fav} = 0;
    }

    #国選択肢リスト
    my $country_hash = $oprof->get_prof_country_hash();
    if ( $prof->{prof_country} ) {
        $prof->{prof_country_name} = $country_hash->{ $prof->{prof_country} };
    }
    if ( $prof->{prof_residence} ) {
        $prof->{prof_residence_name} = $country_hash->{ $prof->{prof_residence} };
    }

    #クチコミを取得
    my $obuz    = new FCC::Class::Buzz( conf => $self->{conf}, db => $self->{db} );
    my $buz_res = $obuz->get_list(
        {
            prof_id  => $prof_id,
            buz_show => 1,
            offset   => 0,
            limit    => 100,
            sort     => [ [ "buz_id", "DESC" ] ]
        }
    );
    my $buz_list = $buz_res->{list};

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
    my $course_list = $course_res->{list};

    #カテゴリー取得
    my $occate = new FCC::Class::Ccate( conf => $self->{conf}, db => $self->{db} );
    my $ccates = $occate->get_all();

    $context->{prof}        = $prof;
    $context->{buz_list}    = $buz_list;
    $context->{course_list} = $course_list;
    $context->{ccates}      = $ccates;
    return $context;
}

1;
