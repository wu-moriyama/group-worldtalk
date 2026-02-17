package FCC::Action::Admin::SlscnttsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use Date::Pcalc;
use Unicode::Japanese;
use FCC::Class::Salescount;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $type = $self->{q}->param("type");
    my $sdate = $self->{q}->param("s_sdate");
    my $edate = $self->{q}->param("s_edate");

    unless ($sdate) {
        my ( $Y, $M, $D ) = Date::Pcalc::Today();
        $sdate = $Y . "-" . sprintf( "%02d", $M ) . "-" . sprintf( "%02d", $D );
    }
    unless ($edate) {
        my ( $Y, $M ) = Date::Pcalc::Today();
        my $D = Date::Pcalc::Days_in_Month( $Y, $M );
        $edate = $Y . "-" . sprintf( "%02d", $M ) . "-" . sprintf( "%02d", $D );
    }

    my $oslscnt =
      new FCC::Class::Salescount( conf => $self->{conf}, db => $self->{db} );
    eval {
        my ( $sepoch, $eepoch ) = $oslscnt->check_date_range( $sdate, $edate );
    };
    if ($@) {
        $context->{fatalerrs} = ["開始日と終了日を正しく入力してください。"];
        return $context;
    }

    my $csv = "";
    my $fname = "";

    if($type == 1) {
        # クーポン管理 cpnact の「入金（会員登録）」のレコード
        $csv = $oslscnt->csv1( $sdate, $edate );
        $fname = "coupon_in_mbrreg_sum_${sdate}_${edate}.csv";
    } elsif($type == 2) {
        # ポイント管理 mbract の「出金（有効期限切れ）」のレコード
        $csv = $oslscnt->csv2( $sdate, $edate );
        $fname = "point_out_expired_sum_${sdate}_${edate}.csv";
    } elsif($type == 3) {
        # ポイント管理 mbract の「入金（管理者より付与）」のレコード
        $csv = $oslscnt->csv3( $sdate, $edate );
        $fname = "point_in_admin_sum_${sdate}_${edate}.csv";
    } elsif($type == 4) {
        # クーポン管理 cpnact の「出金（有効期限切れ）」のレコード
        $csv = $oslscnt->csv4( $sdate, $edate );
        $fname = "coupon_out_expired_sum_${sdate}_${edate}.csv";
    } elsif($type == 5) {
        # レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」のレコード
        $csv = $oslscnt->csv5( $sdate, $edate );
        $fname = "lesson_sum_${sdate}_${edate}.csv";
    } elsif($type == 6) {
        # クーポン管理 cpnact の「入金（管理者より付与）」のレコード
        $csv = $oslscnt->csv6( $sdate, $edate );
        $fname = "coupon_in_admin_sum_${sdate}_${edate}.csv";

    } elsif($type == 7) {
        # ポイント管理 mbract の「出金（動画コースの購入）」のレコード
        $csv = $oslscnt->csv7( $sdate, $edate );
        $fname = "point_out_movie_sum_${sdate}_${edate}.csv";

    } elsif($type == 8) {
        # ポイント管理 mbract の「入金（銀行振込単発チケット購入）」のレコード
        $csv = $oslscnt->csv8( $sdate, $edate );
        $fname = "point_in_bank_sum_${sdate}_${edate}.csv";

    } elsif($type == 9) {
        # カード決済管理 card のレコード
        $csv = $oslscnt->csv9( $sdate, $edate );
        $fname = "card_sum_${sdate}_${edate}.csv";

    } elsif($type == 10) {
        # レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」の講師配分のレコード
        $csv = $oslscnt->csv10( $sdate, $edate );
        $fname = "lesson_prof_sum_${sdate}_${edate}.csv";
    } else {
        $context->{fatalerrs} = ["type が不正です。"];
        return $context;
    }

    $context->{csv} = $csv;
    $context->{length} = length $csv;
    $context->{fname} = $fname;
    return $context;
}

1;
