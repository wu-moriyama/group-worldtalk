package FCC::Action::Prof::CoudplAction;
$VERSION = 1.00;

use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Course;
use File::Copy;

sub dispatch {
    my ($self) = @_;
    my $context = {};
    my $prof_id = $self->{session}->{data}->{prof}->{prof_id};

    my $course_id = $self->{q}->param("course_id");

    if (!$course_id || $course_id =~ /[^\d]/) {
        $context->{fatalerrs} = ["不正なcourse_idです。"];
        return $context;
    }

    # 講師側 pkey（generate_digest）
    my $pkey = $self->{session}->generate_digest();

    # Course クラス
    my $ocourse = FCC::Class::Course->new(
        conf => $self->{conf},
        db   => $self->{db},
        pkey => $pkey,   # ← ここが必要！
        q    => $self->{q}
    );

    # 元レコード取得
    my $orig = $ocourse->get($course_id);
    if (!$orig || $orig->{prof_id} != $prof_id) {
        $context->{fatalerrs} = ["この講座は複製できません。"];
        return $context;
    }

    # 新規データ
    my %new = %{$orig};
    delete $new{course_id};
    $new{course_status} = 0;
    $new{course_logo}   = 0;
    $new{course_cdate}  = undef;
    $new{course_mdate}  = undef;

    # ★ add() は pkey を使わない（講師仕様）
    my $added = $ocourse->add(\%new);
    my $new_id = $added->{course_id};

    # 画像コピー（代表画像は存在しないのでスキップ）
    for my $s (1..3) {
        for my $ext ("jpg", "png") {

            my $src = "$self->{conf}->{course_logo_dir}/$course_id.$s.$ext";
            next unless -e $src;

            my $dst = "$self->{conf}->{course_logo_dir}/$new_id.$s.$ext";

            File::Copy::copy($src, $dst);
        }
    }

    $ocourse->mod({
        course_id      => $new_id,
        course_logo_up => 1,   # ← 最重要！
        course_logo    => 1,   # （念のため）
    }, $pkey);

    # リダイレクト
    my $url = "$self->{conf}->{CGI_URL}?m=coumodfrm&course_id=$new_id";
    print "Location: $url\n\n";
    exit;
}

1;
