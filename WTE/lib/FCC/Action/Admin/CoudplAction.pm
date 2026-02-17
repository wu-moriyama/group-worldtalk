package FCC::Action::Admin::CoudplAction;
$VERSION = 1.00;

use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Course;
use File::Copy;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $course_id = $self->{q}->param("course_id");

    # course_id チェック
    if (!$course_id || $course_id =~ /[^\d]/) {
        $context->{fatalerrs} = ["不正なcourse_idです。"];
        return $context;
    }

    # pkey 生成（WTE公式）
    my $pkey = $self->{session}->generate_sid();

    # Course インスタンス作成（pkey必須）
    my $ocourse = FCC::Class::Course->new(
        conf => $self->{conf},
        db   => $self->{db},
        pkey => $pkey,
        q    => $self->{q}
    );

    # 元レコード取得
    my $orig = $ocourse->get($course_id);
    if (!$orig) {
        $context->{fatalerrs} = ["対象の講座が存在しません。"];
        return $context;
    }

    # 新規レコード作成
    my %new = %{$orig};
    delete $new{course_id};
    $new{course_status} = 0;
    $new{course_cdate}  = undef;
    $new{course_mdate}  = undef;
    $new{course_logo}   = 0;

    # INSERT
    my $added = $ocourse->add(\%new);
    my $new_id = $added->{course_id};

    # サムネイル（代表アイキャッチ）
    for my $ext ("jpg", "png") {
        my $src = "$self->{conf}->{course_logo_dir}/$course_id.$ext";
        my $dst = "$self->{conf}->{course_logo_dir}/$new_id.$ext";
        if (-e $src) {
            File::Copy::copy($src, $dst);
        }
    }

    # NEW: 代表画像を 1番画像としてもコピー（WTE一覧対策）
    for my $ext ("jpg", "png") {
        my $src = "$self->{conf}->{course_logo_dir}/$course_id.$ext";
        my $dst = "$self->{conf}->{course_logo_dir}/$new_id.1.$ext";
        if (-e $src && ! -e $dst) {
            File::Copy::copy($src, $dst);
        }
    }

    # 1〜3番画像
    for my $s (1..3) {

        my $src_jpg = "$self->{conf}->{course_logo_dir}/$course_id.$s.jpg";
        my $src_png = "$self->{conf}->{course_logo_dir}/$course_id.$s.png";

        my $dst_jpg = "$self->{conf}->{course_logo_dir}/$new_id.$s.jpg";
        my $dst_png = "$self->{conf}->{course_logo_dir}/$new_id.$s.png";

        if (-e $src_jpg) {
            File::Copy::copy($src_jpg, $dst_jpg);
        }
        elsif (-e $src_png) {
            File::Copy::copy($src_png, $dst_png);
        }
    }



    # ロゴフラグON
    $ocourse->mod({
        course_id   => $new_id,
        course_logo => 1,
        course_logo_up => 1,
        pkey           => $pkey,  # ← 必須
    });

    # リダイレクト
    my $url = "$self->{conf}->{CGI_URL}?m=coumodfrm&course_id=$new_id";
    print "Location: $url\n\n";
    exit;
}

1;
