package FCC::View::Prof::CoumodsetView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Prof::_SuperView);

sub dispatch {
    my ( $self, $context ) = @_;

    #システムエラーの評価
    if ( $context->{fatalerrs} ) {
        $self->error( $context->{fatalerrs} );
        exit;
    }

    #プロセスキー
    my $pkey = $context->{proc}->{pkey};
    my $course_id = $context->{proc}->{in}->{course_id} || $self->{q}->param("course_id") || "";
    #
    if ( @{ $context->{proc}->{errs} } ) {
        my $rurl = $self->{conf}->{CGI_URL} . "?m=coumodfrm&pkey=${pkey}&course_id=${course_id}";
        print "Location: ${rurl}\n\n";
    }
    elsif ( $context->{save_only} ) {
        # 保存のみ成功：編集画面へ戻す（その場で保存しました）
        my $rurl = $self->{conf}->{CGI_URL} . "?m=coumodfrm&pkey=${pkey}&course_id=${course_id}&saved=1";
        print "Location: ${rurl}\n\n";
    }
    else {
        my $rurl = $self->{conf}->{CGI_URL} . "?m=coumodcpt&pkey=${pkey}";
        print "Location: ${rurl}\n\n";
    }
}

1;
