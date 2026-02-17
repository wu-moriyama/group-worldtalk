package FCC::Action::Admin::SlscntfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use Date::Pcalc;
use FCC::Class::Salescount;

sub dispatch {
    my ($self) = @_;
    my $context = {};

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

    my $counts = {

        # クーポン管理 cpnact の「入金（会員登録）」の各レコード合算金額
        "sum_1" => $oslscnt->count1( $sdate, $edate ),

        # ポイント管理 mbract の「出金（有効期限切れ）」の各レコード合算金額
        "sum_2" => $oslscnt->count2( $sdate, $edate ),

        # ポイント管理 mbract の「入金（管理者より付与）」の各レコード合算金額
        "sum_3" => $oslscnt->count3( $sdate, $edate ),

        # クーポン管理 cpnact の「出金（有効期限切れ）」の各レコード合算金額
        "sum_4" => $oslscnt->count4( $sdate, $edate ),

        # レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」の各レコード合算金額
        "sum_5" => $oslscnt->count5( $sdate, $edate ),

        # クーポン管理 cpnact の「入金（管理者より付与）」の各レコード合算金額
        "sum_6" => $oslscnt->count6( $sdate, $edate ),

        # ポイント管理 mbract の「出金（動画コースの購入）」の各レコード合算金額
        "sum_7" => $oslscnt->count7( $sdate, $edate ),

        # ポイント管理 mbract の「入金（銀行振込単発チケット購入）」の各レコード合算金額
        "sum_8" => $oslscnt->count8( $sdate, $edate ),

        # カード決済管理 card の各レコード合算金額
        "sum_9" => $oslscnt->count9( $sdate, $edate )
    };

    $context->{counts} = $counts;
    $context->{sdate}  = $sdate;
    $context->{edate}  = $edate;
    return $context;
}

1;
