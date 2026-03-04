package FCC::Class::Lesson;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use FCC::Class::Log;
use FCC::Class::Date::Utils;
use FCC::Class::Schedule;
use FCC::Class::Member;
use Unicode::Japanese;
use CGI;
use Data::Dumper;
use Time::Piece;
use Time::Seconds;

sub init {
    my ( $self, %args ) = @_;
    unless ( $args{conf} && $args{db} ) {
        croak "parameters are lacking.";
    }
    $self->{conf} = $args{conf};
    $self->{db}   = $args{db};

    #lessonsテーブルの全カラム名のリスト
    $self->{table_cols} = {
        lsn_id                 => "識別ID",
        prof_id                => "講師識別ID",
        member_id              => "予約した会員識別ID",
        seller_id              => "予約した会員が属する代理店識別ID",
        course_id              => "授業識別ID",
        lsn_cdate              => "会員予約日時",
        lsn_stime              => "レッスン開始時刻",
        lsn_etime              => "レッスン終了時刻",
        lsn_cancel             => "通常キャンセルフラグ",
        lsn_cancel_date        => "キャンセル日時",
        lsn_cancel_reason      => "キャンセル理由",
        lsn_prof_repo          => "講師報告",
        lsn_prof_repo_date     => "講師報告日時",
        lsn_prof_repo_note     => "講師報告メモ",
        lsn_member_repo        => "生徒報告",
        lsn_member_repo_date   => "会員報告日時",
        lsn_member_repo_note   => "会員報告メモ",
        lsn_member_repo_rating => "会員報告評価",
        lsn_review             => "会員の感想",
        lsn_review_show        => "会員の感想の表示フラグ",
        lsn_status             => "ステータス",
        lsn_status_date        => "ステータス確定日時",
        lsn_prof_fee           => "レッスン料金",
        lsn_pay_type           => "支払種別",
        coupon_id              => "クーポン識別ID",
        lsn_pay_fee_rate       => "配分ベース比率",
        lsn_base_price         => "配分ベース料金",
        lsn_prof_margin        => "講師への分配マージン比率",
        lsn_prof_price         => "講師への支払金額",
        lsn_seller_margin      => "代理店への分配マージン比率",
        lsn_seller_price       => "代理店への支払金額",
        lsn_latest_msg_1       => "最新の会員からのメッセージ",
        lsn_latest_msg_2       => "最新の講師からのメッセージ"
    };

    #CSVの各カラム名と名称とepoch秒フラグ（lsn_idは必ず0番目にセットすること）
    my $lsn_prof_repo_cap = {
        "0" => "未報告",
        "1" => "完了",
        "2" => "未実施（相手が来ない）",
        "3" => "トラブル（自分）",
        "9" => "その他"
    };
    my $lsn_member_repo_cap = {
        "0" => "未報告",
        "1" => "完了",
        "2" => "未実施（相手が来ない）",
        "3" => "トラブル（自分）",
        "9" => "その他"
    };
    my $lsn_status_cap = {
        "0"  => "未確定",
        "1"  => "完了（会員講師ともに完了報告済）",
        "11" => "会員による通常キャンセル",
        "12" => "会員による緊急キャンセル",
        "13" => "会員による放置（すっぽかし）キャンセル",
        "21" => "講師による通常キャンセル（非課金）",
        "22" => "講師による緊急キャンセル（非課金）",
        "23" => "講師による放置（すっぽかし）キャンセル（非課金）",
        "29" => "その他の理由による非課金",
        "31" => "払い戻し",
    };
    $self->{csv_cols} = [
        [ "lessons.lsn_id",           "レッスン識別ID" ],
        [ "courses.course_id",        "授業識別ID" ],
        [ "courses.course_name",      "授業名" ],
        [ "lessons.prof_id",          "講師の識別ID" ],
        [ "profs.prof_lastname",      "姓" ],
        [ "profs.prof_firstname",     "名" ],
        [ "profs.prof_handle",        "ニックネーム" ],
        [ "lessons.member_id",        "$self->{conf}->{member_caption}識別ID" ],
        [ "members.member_lastname",  "姓" ],
        [ "members.member_firstname", "名" ],
        [ "members.member_handle",    "ニックネーム" ],
        [ "lessons.lsn_cdate",         "会員予約日時",             1 ],
        [ "lessons.lsn_stime",         "レッスン開始時刻" ],
        [ "lessons.lsn_etime",         "レッスン終了時刻" ],
        [ "lessons.lsn_cancel",        "通常キャンセルフラグ", 0, { "0" => "", "1" => "会員によるキャンセル", "2" => "講師によるキャンセル" } ],
        [ "lessons.lsn_cancel_date",   "キャンセル日時",          1 ],
        [ "lessons.lsn_cancel_reason", "キャンセル理由" ],
        [ "lessons.lsn_prof_repo",      "講師レッスン完了状況報告", 0, $lsn_prof_repo_cap ],
        [ "lessons.lsn_prof_repo_date", "講師レッスン完了報告日時", 1 ],
        [ "lessons.lsn_prof_repo_note", "講師レッスン完了報告説明" ],
        [ "lessons.lsn_member_repo",    "会員レッスン完了状況報告", 0, $lsn_member_repo_cap ],
        [ "lessons.lsn_member_repo_date",   "会員レッスン完了報告日時", 1 ],
        [ "lessons.lsn_member_repo_note",   "会員レッスン完了報告説明" ],
        [ "lessons.lsn_member_repo_rating", "会員レッスン評価" ],
        [ "lessons.lsn_review",             "会員レッスン感想" ],
        [ "lessons.lsn_review_show",        "会員レッスン感想の表示フラグ" ],
        [ "lessons.lsn_status",      "ステータス",             0, $lsn_status_cap ],
        [ "lessons.lsn_status_date", "ステータス確定日時", 1 ],
        [ "lessons.lsn_prof_fee",    "レッスン料金" ],
        [ "lessons.lsn_pay_type", "支払種別", 0, { "1" => "ポイント", "2" => "クーポン" } ],
        [ "lessons.coupon_id",         "クーポン識別ID" ],
        [ "lessons.lsn_pay_fee_rate",  "配分ベース比率" ],
        [ "lessons.lsn_base_price",    "配分ベース料金" ],
        [ "lessons.lsn_prof_margin",   "講師への分配マージン比率" ],
        [ "lessons.lsn_prof_price",    "講師への支払金額" ],
        [ "lessons.lsn_seller_margin", "代理店への分配マージン比率" ],
        [ "lessons.lsn_seller_price",  "代理店への支払金額" ],
        [ "lessons.lsn_charged_date", "ポイント引き落とし日時", 1 ],
        [ "lessons.pdm_id",           "講師からの請求識別ID" ],
        [ "lessons.lsn_pdm_status",   "講師への支払ステータス" ],
        [ "lessons.sdm_id",           "代理店からの請求識別ID" ],
        [ "lessons.lsn_sdm_status",   "代理店への支払ステータス" ]
    ];
    #
    $self->{now} = time;
    my @tm = FCC::Class::Date::Utils->new( time => $self->{now}, tz => $self->{conf}->{tz} )->get(1);
    $self->{nowYMDhm} = "$tm[0]$tm[1]$tm[2]$tm[3]$tm[4]";
    #
    my @country_lines = split( /\n+/, $self->{conf}->{prof_countries} );
    $self->{prof_country_hash} = {};
    $self->{prof_country_list} = [];
    for my $line (@country_lines) {
        if ( $line =~ /^([a-z]{2})\s+(.+)/ ) {
            my $code = $1;
            my $name = $2;
            $self->{prof_country_hash}->{$code} = $name;
            push( @{ $self->{prof_country_list} }, [ $code, $name ] );
        }
    }
}

#---------------------------------------------------------------------
#■会員から現在レッスン中のレッスンを取得
#---------------------------------------------------------------------
#[引数]
#  1.会員識別ID（必須）
#[戻り値]
#  レッスン情報を格納したhashrefを返す
#---------------------------------------------------------------------
sub get_during {
    my ( $self, $member_id ) = @_;
    if ( !$member_id || $member_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    my @tm     = FCC::Class::Date::Utils->new( time => time, tz => $self->{conf}->{tz} )->get(1);
    my $now_dt = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SELECT
    my $sql = "SELECT lessons.*, profs.*, courses.* FROM lessons";
    $sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
    $sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
    $sql .= " WHERE lessons.member_id=${member_id} AND lessons.lsn_stime<='${now_dt}' AND lessons.lsn_etime>'${now_dt}' AND lessons.lsn_cancel=0";
    my $ref = $dbh->selectrow_hashref($sql);
    if ($ref) {
        $self->add_datetime_info($ref);
        $self->add_prof_info($ref);
        $self->add_course_info($ref);
    }
    return $ref;
}

#---------------------------------------------------------------------
#■現在のレッスンが延長可能かどうか
#---------------------------------------------------------------------
#[引数]
#  1.現在受講中のレッスン識別ID（必須）
#[戻り値]
#  hashref
#  {
#    extendable => 延長可否フラグ（0:不可、1:可能）,
#    reason     => 延長不可理由コード,
#    message    => 延長不可理由メッセージ,
#    member     => 会員情報のhashref
#    lsn        => 指定のレッスン情報のhashref,
#    sch        => 延長対象のスケジュール枠のhashref（登録されていれば）
#  }
#
#  ※延長不可理由コード
#  1: 指定のレッスンが存在しない,
#  2: 現在授業中でない
#  3: 会員が存在しない、または、会員ステータスが1でない
#  4: 会員がダブルブッキング
#  5: 講師がダブルブッキング
#  6: ポイントの残高が足りない
#  7: クーポンの残高が足りない
#
#  ※レッスンの延長にかかる料金は、元のレッスンの支払い種別と同じ。
#    ポイント払いだった場合は、延長もポイント払いとなり、クーポン払い
#    だった場合は、延長もクーポン払いとなる。
#---------------------------------------------------------------------
sub is_extendable {
    my ( $self, $lsn_id ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    my $res = {
        extendable => 0,
        reason     => 0,
        message    => "",
    };

    #指定のレッスンが存在するかどうかをチェック
    my $lsn = $self->get($lsn_id);
    if ( !$lsn || $lsn->{lsn_cancel} > 0 ) {
        $res->{reason}  = 1;
        $res->{message} = "指定のレッスンが存在しませんでした。";
        return $res;
    }
    $res->{lsn} = $lsn;

    #現時点で指定のレッスンが授業中なのかをチェック
    if ( !$lsn->{lsn_during} ) {
        $res->{reason}  = 2;
        $res->{message} = "指定のレッスンは現在レッスン中でないため、レッスンを延長できません。";
        return $res;
    }

    #会員の存在をチェック
    my $member_id = $lsn->{member_id};
    my $member    = FCC::Class::Member->new( conf => $self->{conf}, db => $self->{db}, memd => $self->{memd} )->get_from_db($member_id);
    $res->{member} = $member;
    if ( !$member || $member->{member_status} != 1 ) {
        $res->{reason}  = 3;
        $res->{message} = "会員情報が見つからない、または、会員状態が適切ではないため、レッスンを延長できません。";
        return $res;
    }

    #会員同じ時間に予約が重複していないかを確認
    my $sY          = $lsn->{lsn_etime_Y};
    my $sM          = $lsn->{lsn_etime_m};
    my $sD          = $lsn->{lsn_etime_d};
    my $sh          = $lsn->{lsn_etime_H};
    my $sm          = $lsn->{lsn_etime_i};
    my $stime       = $sY . $sM . $sD . $sh . $sm;
    my $stime_epoch = FCC::Class::Date::Utils->new( iso => "${sY}-${sM}-${sD} ${sh}:${sm}:00", tz => $self->{conf}->{tz} )->epoch();
    my %etime_fmt   = FCC::Class::Date::Utils->new( time => $stime_epoch + ( 60 * $lsn->{prof_step} ), tz => $self->{conf}->{tz} )->get_formated();
    my $etime       = $etime_fmt{Y} . $etime_fmt{m} . $etime_fmt{d} . $etime_fmt{H} . $etime_fmt{i};

    if ( $self->is_double_booking( $member_id, $stime, $etime ) ) {
        $res->{reason}  = 4;
        $res->{message} = "$self->{conf}->{member_caption}側で、すでに別の予約が登録されているため、レッスンを延長できません。";
        return $res;
    }

    #講師が同じ時間に予約が重複していないかを確認
    my $prof_id = $lsn->{prof_id};
    my $osch    = new FCC::Class::Schedule( conf => $self->{conf}, db => $self->{db} );
    my $sch     = $osch->get_from_stime( $prof_id, $stime );
    if ( $sch && $sch->{lsn_id} ) {
        $res->{reason}  = 5;
        $res->{message} = "$self->{conf}->{prof_caption}側で、すでに別の予約が登録されているため、レッスンを延長できません。";
        return $res;
    }
    $res->{sch} = $sch;

    #会員のポイント残高をチェック
    if ( $lsn->{lsn_pay_type} == 1 ) {
        my $receivable_point = $self->get_receivable( $member_id, 1 );         # ポイントの売り掛け
        my $available_point  = $member->{member_point} - $receivable_point;    # 実質的に利用可能なポイント
        if ( $available_point < $lsn->{prof_fee} ) {
            $res->{reason}  = 6;
            $res->{message} = "ポイント残高不足のため、レッスンを延長できません。";
            return $res;
        }
    }
    else {
        my $receivable_coupon = $self->get_receivable( $member_id, 2 );           # クーポンの売り掛け
        my $available_coupon  = $member->{member_coupon} - $receivable_coupon;    # 実質的に利用可能なクーポン
        if ( $available_coupon < $lsn->{prof_fee} ) {
            $res->{reason}  = 7;
            $res->{message} = "クーポン残高不足のため、レッスンを延長できません。";
            return $res;
        }
    }
    #
    $res->{extendable} = 1;
    return $res;
}

#---------------------------------------------------------------------
#■キャンセル登録の入力チェック
#---------------------------------------------------------------------
#[引数]
#  1.入力データのキーのarrayref（必須）
#  2.入力データのhashref（必須）
#[戻り値]
#  エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub cancel_input_check {
    my ( $self, $names, $in, $mode ) = @_;
    my @errs;
    for my $k ( @{$names} ) {
        my $v = $in->{$k};
        if ( !defined $v ) { $v = ""; }
        my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();

        #キャンセル理由
        if ( $k eq "lsn_cancel_reason" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"キャンセル理由\" は必須です。" ] );
            }
            elsif ( $len > 140 ) {
                push( @errs, [ $k, "\"キャンセル理由\" は140文字以内で入力してください。" ] );
            }
        }
    }
    return @errs;
}

#---------------------------------------------------------------------
#■レッスン・キャンセル（会員用）
#---------------------------------------------------------------------
#[引数]
#  1:レッスン識別ID
#  2:メモ
#  3:該当レッスンのhashref（必須ではないが、指定するとパフォーマンスがよい）
#[戻り値]
#  該当のレッスンのhashref
#---------------------------------------------------------------------
sub member_cancel_set {
    my ( $self, $lsn_id, $lsn_cancel_reason, $lsn ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( $lsn && ( ref($lsn) ne "HASH" || $lsn->{lsn_id} != $lsn_id ) ) {
        croak "a parameter is invalid.";
    }
    unless ($lsn) {
        $lsn = $self->get($lsn_id);
        unless ($lsn) {
            croak "a parameter is invalid.";
        }
    }
    if ( $lsn->{lsn_cancelable} !~ /^(1|2)$/ ) {
        croak "the specified lesson is not cancelable.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();


    #SELECT
    my $sql = "SELECT course_id,lsn_stime FROM lessons where lsn_id = ${lsn_id}";
    my $ref = $dbh->selectrow_hashref($sql);
    #print "Content-type: text/html\n\ntest.\n";

    my $course_id = $ref->{course_id};
    my $lsn_stime = $ref->{lsn_stime};

    my $sql = "SELECT group_id FROM schedules where course_id=${course_id} AND sch_stime='${lsn_stime}'";
    my $ref = $dbh->selectrow_hashref($sql);

    my $group_id = $ref->{group_id};

    if($group_id){

      my $last_sql;
      $last_sql = "UPDATE schedules SET group_count = group_count + 1 WHERE group_id=${group_id}";
      $dbh->do($last_sql);
      $dbh->commit();

    }
    #exit(1);

    #アップデート
    my $last_sql;
    eval {
        my $q_lsn_cancel_reason = $dbh->quote($lsn_cancel_reason);
        my $lsn_cancel_date     = time;
        $last_sql = "UPDATE lessons SET lsn_cancel=1, lsn_cancel_date=${lsn_cancel_date}, lsn_cancel_reason=${q_lsn_cancel_reason} WHERE lsn_id=${lsn_id}";
        $dbh->do($last_sql);
        #
        $last_sql = "UPDATE schedules SET lsn_id=0 WHERE lsn_id=${lsn_id}";
        $dbh->do($last_sql);
        #
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update a lesson record in lessons table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #ステータス・アップデート
    if ( $lsn->{lsn_cancelable} == 1 ) {
        $lsn = $self->update_status( $lsn_id, 11, $lsn );
    }
    elsif ( $lsn->{lsn_cancelable} == 2 ) {
        $lsn = $self->update_status( $lsn_id, 12, $lsn );
    }
    #
    return $lsn;
}

#---------------------------------------------------------------------
#■レッスン・キャンセル（講師用）
#---------------------------------------------------------------------
#[引数]
#  1:レッスン識別ID
#  2:メモ
#  3:該当レッスンのhashref（必須ではないが、指定するとパフォーマンスがよい）
#[戻り値]
#  該当のレッスンのhashref
#---------------------------------------------------------------------
sub prof_cancel_set {
    my ( $self, $lsn_id, $lsn_cancel_reason, $lsn ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( $lsn && ( ref($lsn) ne "HASH" || $lsn->{lsn_id} != $lsn_id ) ) {
        croak "a parameter is invalid.";
    }
    unless ($lsn) {
        $lsn = $self->get($lsn_id);
        unless ($lsn) {
            croak "a parameter is invalid.";
        }
    }
    if ( $lsn->{lsn_cancelable} !~ /^(1|2)$/ ) {
        croak "the specified lesson is not cancelable.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #アップデート
    my $last_sql;
    eval {
        my $q_lsn_cancel_reason = $dbh->quote($lsn_cancel_reason);
        my $lsn_cancel_date     = time;
        $last_sql = "UPDATE lessons SET lsn_cancel=2, lsn_cancel_date=${lsn_cancel_date}, lsn_cancel_reason=${q_lsn_cancel_reason} WHERE lsn_id=${lsn_id}";
        $dbh->do($last_sql);
        #
        $last_sql = "UPDATE schedules SET lsn_id=0 WHERE lsn_id=${lsn_id}";
        $dbh->do($last_sql);
        #
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update a lesson record in lessons table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #ステータス・アップデート
    if ( $lsn->{lsn_cancelable} == 1 ) {
        $lsn = $self->update_status( $lsn_id, 21, $lsn );
    }
    elsif ( $lsn->{lsn_cancelable} == 2 ) {
        $lsn = $self->update_status( $lsn_id, 22, $lsn );
    }
    #
    return $lsn;
}

#---------------------------------------------------------------------
#■レッスン報告の入力チェック（講師用）
#---------------------------------------------------------------------
#[引数]
#  1.入力データのキーのarrayref（必須）
#  2.入力データのhashref（必須）
#[戻り値]
#  エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub prof_repo_input_check {
    my ( $self, $names, $in ) = @_;
    my @errs;
    for my $k ( @{$names} ) {
        my $v = $in->{$k};
        if ( !defined $v ) { $v = ""; }
        my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();

        #講師レッスン完了状況報告
        if ( $k eq "lsn_member_repo" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"レッスン完了状況報告\" は必須です。" ] );
            }
            elsif ( $v !~ /^(1|2|3|9)$/ ) {
                push( @errs, [ $k, "\"レッスン完了状況報告\" に不正な値が送信されました。" ] );
            }

            #講師レッスン完了報告説明
        }
        elsif ( $k eq "lsn_member_repo_note" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 140 ) {
                push( @errs, [ $k, "\"レッスン完了報告説明\" は140文字以内で入力してください。" ] );
            }
        }
    }
    return @errs;
}

#---------------------------------------------------------------------
#■レッスン報告をセット（講師用）
#---------------------------------------------------------------------
#[引数]
#  1:hashref
#    {
#      lsn_id => レッスン識別ID,
#      lsn_prof_repo => レッスン完了状況報告コード,
#      lsn_prof_repo_note => レッスン完了状況報告説明
#    }
#  2:該当レッスンのhashref（必須ではないが、指定するとパフォーマンスがよい）
#[戻り値]
#  該当のレッスンのhashref
#---------------------------------------------------------------------
sub prof_repo_set {
    my ( $self, $ref, $lsn ) = @_;
    my $lsn_id             = $ref->{lsn_id};
    my $lsn_prof_repo      = $ref->{lsn_prof_repo};
    my $lsn_prof_repo_note = $ref->{lsn_prof_repo_note};
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( !$lsn_prof_repo || $lsn_prof_repo =~ /[^\d]/ || $lsn_prof_repo !~ /^(0|1|2|3|9)$/ ) {
        croak "a parameter is invalid.";
    }
    if ( $lsn && ( ref($lsn) ne "HASH" || $lsn->{lsn_id} != $lsn_id ) ) {
        croak "a parameter is invalid.";
    }
    unless ($lsn) {
        $lsn = $self->get($lsn_id);
        unless ($lsn) {
            croak "a parameter is invalid.";
        }
    }

    #アップデート
    my $rec = {
        lsn_id             => $lsn_id,
        lsn_prof_repo      => $lsn_prof_repo,
        lsn_prof_repo_note => $lsn_prof_repo_note,
        lsn_prof_repo_date => time
    };
    $lsn = $self->mod($rec);

    #ステータスを判定
    my $lsn_status = $self->determine_lsn_status( $lsn_prof_repo, $lsn->{lsn_member_repo} );

    #ステータス・アップデート
    if ( $lsn_status > 0 ) {
        $lsn = $self->update_status( $lsn_id, $lsn_status, $lsn );
    }
    #
    return $lsn;
}

#---------------------------------------------------------------------
#■レッスン報告の入力チェック（会員用）
#---------------------------------------------------------------------
#[引数]
#  1.入力データのキーのarrayref（必須）
#  2.入力データのhashref（必須）
#[戻り値]
#  エラー情報を格納した配列を返す。
#---------------------------------------------------------------------
sub member_repo_input_check {
    my ( $self, $names, $in ) = @_;
    my @errs;
    for my $k ( @{$names} ) {
        my $v = $in->{$k};
        if ( !defined $v ) { $v = ""; }
        my $len = FCC::Class::String::Checker->new( $v, "utf8" )->get_char_num();

        #会員レッスン完了状況報告
        if ( $k eq "lsn_member_repo" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"レッスン完了状況報告\" は必須です。" ] );
            }
            elsif ( $v !~ /^(1|2|3|9)$/ ) {
                push( @errs, [ $k, "\"レッスン完了状況報告\" に不正な値が送信されました。" ] );
            }

            #会員レッスン完了報告説明
        }
        elsif ( $k eq "lsn_member_repo_note" ) {
            if ( $v eq "" ) {

            }
            elsif ( $len > 140 ) {
                push( @errs, [ $k, "\"レッスン完了報告説明\" は140文字以内で入力してください。" ] );
            }

            #評価
        }
        elsif ( $k eq "lsn_member_repo_rating" ) {
            if ( $v eq "" ) {
                push( @errs, [ $k, "\"評価\" は必須です。" ] );
            }
            elsif ( $v !~ /^(1|2|3|4|5)$/ ) {
                push( @errs, [ $k, "\"評価\" に不正な値が送信されました。" ] );
            }

            #感想
        }
        elsif ( $k eq "lsn_review" ) {
            if ( $v eq "" ) {

                #				push(@errs, [$k, "\"感想\" は必須です。"]);
            }
            elsif ( $len > 140 ) {
                push( @errs, [ $k, "\"感想\" は140文字以内���入力してください。" ] );
            }
        }
    }
    return @errs;
}

#---------------------------------------------------------------------
#■レッスン報告をセット（会員用）
#---------------------------------------------------------------------
#[引数]
#  1:hashref
#    {
#      lsn_id => レッスン識別ID,
#      lsn_member_repo => レッスン完了状況報告コード,
#      lsn_member_repo_note => レッスン完了状況報告説明,
#      lsn_member_repo_rating => レッスン評価,
#      lsn_review => 感想
#    }
#  2:該当レッスンのhashref（必須ではないが、指定するとパフォーマンスがよい）
#[戻り値]
#  該当のレッスンのhashref
#---------------------------------------------------------------------
sub member_repo_set {
    my ( $self, $ref, $lsn ) = @_;
    my $lsn_id                 = $ref->{lsn_id};
    my $lsn_member_repo        = $ref->{lsn_member_repo};
    my $lsn_member_repo_note   = $ref->{lsn_member_repo_note};
    my $lsn_member_repo_rating = $ref->{lsn_member_repo_rating};
    my $lsn_review             = $ref->{lsn_review};
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( !$lsn_member_repo || $lsn_member_repo =~ /[^\d]/ || $lsn_member_repo !~ /^(0|1|2|3|9)$/ ) {
        croak "a parameter is invalid.";
    }
    if ( $lsn && ( ref($lsn) ne "HASH" || $lsn->{lsn_id} != $lsn_id ) ) {
        croak "a parameter is invalid.";
    }
    unless ($lsn) {
        $lsn = $self->get($lsn_id);
        unless ($lsn) {
            croak "a parameter is invalid.";
        }
    }

    #アップデート
    my $rec = {
        lsn_id                 => $lsn_id,
        lsn_member_repo        => $lsn_member_repo,
        lsn_member_repo_note   => $lsn_member_repo_note,
        lsn_member_repo_rating => $lsn_member_repo_rating,
        lsn_review             => $lsn_review,
        lsn_member_repo_date   => time
    };
    $lsn = $self->mod($rec);

    #ステータスを判定
    my $lsn_status = $self->determine_lsn_status( $lsn->{lsn_prof_repo}, $lsn_member_repo );

    #ステータス・アップデート
    if ( $lsn_status > 0 ) {
        $lsn = $self->update_status( $lsn_id, $lsn_status, $lsn );
    }
    #
    return $lsn;
}

#---------------------------------------------------------------------
#■レッスン報告からステータスを判定（会員・講師がレッスン報告した時点）
#---------------------------------------------------------------------
#[引数]
#  1:講師報告コード
#  2:会員報告コード
#[戻り値]
#  判定ステータスコード
#---------------------------------------------------------------------
sub determine_lsn_status {
    my ( $self, $lsn_prof_repo, $lsn_member_repo ) = @_;
    if ( $lsn_prof_repo == 1 ) {    # 講師が完了の場合
        if ( $lsn_member_repo == 1 ) {    # 会員が完了と報告した場合
            return 1;
        }
    }
    elsif ( $lsn_prof_repo == 2 ) {       # 講師が未実施（相手が来ない）と報告した場合
        if ( $lsn_member_repo == 1 ) {    # 会員が完了と報告した場合
            return 1;
        }
        elsif ( $lsn_member_repo == 3 ) {    # 会員がトラブル（自分）と報告した場合
            return 13;
        }
    }
    elsif ( $lsn_prof_repo == 3 ) {          # 講師がトラブル（自分）と報告した場合
        if ( $lsn_member_repo == 1 ) {       # 会員が完了と報告した場合
            return 1;
        }
        elsif ( $lsn_member_repo == 2 ) {    # 会員が未実施（相手が来ない）と報告した場合
            return 23;
        }
    }
    elsif ( $lsn_prof_repo == 4 ) {          # 講師がその他と報告した場合
        if ( $lsn_member_repo == 1 ) {       # 会員が完了と報告した場合
            return 1;
        }
        elsif ( $lsn_member_repo == 3 ) {    # 会員がトラブル（自分）と報告した場合
            return 13;
        }
    }
    return 0;
}

#---------------------------------------------------------------------
#■ステータスをセット
#---------------------------------------------------------------------
#[引数]
#  1:レッスン識別ID
#  2:ステータス・コード
#  3:該当レッスンのhashref（必須ではないが、指定するとパフォーマンスがよい）
#[戻り値]
#  該当のレッスンのhashref
#---------------------------------------------------------------------
sub update_status {
    my ( $self, $lsn_id, $lsn_status, $lsn ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( !$lsn_status || $lsn_status =~ /[^\d]/ || $lsn_status !~ /^(0|1|11|12|13|21|22|23|29)$/ ) {
        croak "a parameter is invalid.";
    }
    if ( $lsn && ( ref($lsn) ne "HASH" || $lsn->{lsn_id} != $lsn_id ) ) {
        croak "a parameter is invalid.";
    }
    unless ($lsn) {
        $lsn = $self->get($lsn_id);
        unless ($lsn) {
            croak "a parameter is invalid.";
        }
    }
    #
    my $rec = {
        lsn_id            => $lsn_id,
        lsn_status        => $lsn_status,
        lsn_status_date   => time,
        lsn_pay_fee_rate  => 0,
        lsn_base_price    => 0,
        lsn_prof_margin   => 0,
        lsn_prof_price    => 0,
        lsn_seller_margin => 0,
        lsn_seller_price  => 0
    };
    #
    if ( $lsn_status > 0 && $lsn_status < 20 ) {
        if ( $lsn->{lsn_pay_type} == 1 ) {    # ポイント利用時
            if ( $lsn_status == 1 ) {         # 通常完了
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{normal_point_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{normal_point_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{normal_point_seller_margin};
            }
            elsif ( $lsn_status == 11 ) {     # 会員による通常キャンセル
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{cancel1_point_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{cancel1_point_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{cancel1_point_seller_margin};
            }
            elsif ( $lsn_status == 12 ) {     # 会員による緊急キャンセル
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{cancel2_point_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{cancel2_point_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{cancel2_point_seller_margin};
            }
            elsif ( $lsn_status == 13 ) {     # 会員による放置（すっぽかし）キャンセル
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{cancel3_point_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{cancel3_point_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{cancel3_point_seller_margin};
            }
        }
        else {                                # クーポン利用時
            if ( $lsn_status == 1 ) {         # 通常完了
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{normal_coupon_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{normal_coupon_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{normal_coupon_seller_margin};
            }
            elsif ( $lsn_status == 11 ) {     # 会員による通常キャンセル
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{cancel1_coupon_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{cancel1_coupon_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{cancel1_coupon_seller_margin};
            }
            elsif ( $lsn_status == 12 ) {     # 会員による緊急キャンセル
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{cancel2_coupon_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{cancel2_coupon_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{cancel2_coupon_seller_margin};
            }
            elsif ( $lsn_status == 13 ) {     # 会員による放置（すっぽかし）キャンセル
                $rec->{lsn_pay_fee_rate}  = $self->{conf}->{cancel3_coupon_fee_rate};
                $rec->{lsn_prof_margin}   = $self->{conf}->{cancel3_coupon_prof_margin};
                $rec->{lsn_seller_margin} = $self->{conf}->{cancel3_coupon_seller_margin};
            }
        }
        $rec->{lsn_base_price}   = int( $lsn->{lsn_prof_fee} * $rec->{lsn_pay_fee_rate} / 100 );
        $rec->{lsn_prof_price}   = int( $rec->{lsn_base_price} * $rec->{lsn_prof_margin} / 100 );
        $rec->{lsn_seller_price} = int( $rec->{lsn_base_price} * $rec->{lsn_seller_margin} / 100 );
    }

    #アップデート
    my $new_lsn = $self->mod($rec);
    return $new_lsn;
}

#---------------------------------------------------------------------
#■修正
#---------------------------------------------------------------------
#[引数]
#  1.入力データのhashref（必須）
#[戻り値]
#  成功すれば登録データのhashrefを返す。
#  もし存在しないlsn_idが指定されたら、未定義値を返す
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub mod {
    my ( $self, $ref ) = @_;

    #識別IDのチェック
    my $lsn_id = $ref->{lsn_id};
    if ( !defined $lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "the value of lsn_id in parameters is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #更新情報をhashrefに格納
    my $rec = {};
    while ( my ( $k, $v ) = each %{$ref} ) {
        unless ( exists $self->{table_cols}->{$k} ) { next; }
        if     ( $k eq "lsn_id" )                   { next; }
        if     ( defined $v ) {
            $rec->{$k} = $v;
        }
        else {
            $rec->{$k} = "";
        }
    }

    #SQL生成
    my @sets;
    while ( my ( $k, $v ) = each %{$rec} ) {
        my $q_v;
        if ( $v eq "" ) {
            $q_v = "''";
        }
        else {
            $q_v = $dbh->quote($v);
        }
        push( @sets, "${k}=${q_v}" );
    }
    my $sql = "UPDATE lessons SET " . join( ",", @sets ) . " WHERE lsn_id=${lsn_id}";

    #UPDATE
    my $updated;
    my $last_sql;
    eval {
        $last_sql = $sql;
        $updated  = $dbh->do($last_sql);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to update a lesson record in lessons table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #対象のレコードがなければundefを返す
    if ( $updated == 0 ) {
        return undef;
    }
    #
    my $new_lsn = $self->get($lsn_id);
    return $new_lsn;
}

#---------------------------------------------------------------------
#■会員識別IDと支払種別から売掛金を取得
#---------------------------------------------------------------------
#[引数]
#  1:会員識別ID
#  2:支払種別（1:ポイント、2:クーポン）
#[戻り値]
#  売掛金額（レッスンの予約のうち、まだ支払が確定していない金額）
#---------------------------------------------------------------------
sub get_receivable {
    my ( $self, $member_id, $lsn_pay_type ) = @_;
    my $dbh = $self->{db}->connect_db();
    my $sql = "SELECT SUM(lsn_prof_fee) FROM lessons WHERE member_id=${member_id} AND lsn_charged_date=0 AND lsn_pay_type=${lsn_pay_type}";

    # 会員通常キャンセルの配分比率設定が0なら、会員通常キャンセルは対象外とする
    if ( ( $lsn_pay_type == 1 && $self->{conf}->{cancel1_point_fee_rate} == 0 ) || ( $lsn_pay_type == 2 && $self->{conf}->{cancel1_coupon_fee_rate} == 0 ) ) {
        $sql .= " AND NOT lsn_status=11";
        $sql .= " AND NOT lsn_status=21";
        $sql .= " AND NOT lsn_status=22";
        $sql .= " AND NOT lsn_status=23";
    }
    my ($amount) = $dbh->selectrow_array($sql);

    unless ($amount) { $amount = 0; }
    return $amount + 0;
}

#---------------------------------------------------------------------
#■識別IDからレッスン取得
#---------------------------------------------------------------------
#[引数]
#  1:識別ID
#[戻り値]
#  hashrefを返す
#---------------------------------------------------------------------
sub get {
    my ( $self, $lsn_id ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SELECT
    my $sql = "SELECT lessons.*, profs.*, courses.* FROM lessons";
    $sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
    $sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
    $sql .= " WHERE lessons.lsn_id=${lsn_id}";

    my $ref = $dbh->selectrow_hashref($sql);
    if ($ref) {
        $self->add_datetime_info($ref);
        $self->add_prof_info($ref);
        $self->add_course_info($ref);
    }
    return $ref;
}

#---------------------------------------------------------------------
#■会員識別IDと開始日時からレッスン取得
#---------------------------------------------------------------------
#[引数]
#  1:会員識別ID
#  2:開始日時（YYYYMMDDhhmm）
#[戻り値]
#  hashrefを返す
#---------------------------------------------------------------------
sub get_from_stime {
    my ( $self, $member_id, $stime ) = @_;
    if ( !$member_id || $member_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( $stime !~ /^\d{12}$/ ) {
        croak "a parameter is invalid.";
    }
    #
    my ( $Y, $M, $D, $h, $m ) = $stime =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
    my $lsn_stime = "${Y}-${M}-${D} ${h}:${m}:00";

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SELECT
    my $q_lsn_stime = $dbh->quote($lsn_stime);
    my $ref         = $dbh->selectrow_hashref("SELECT * FROM lessons WHERE member_id=${member_id} AND lsn_stime=${q_lsn_stime}");
    if ($ref) {
        $self->add_datetime_info($ref);
        $self->add_prof_info($ref);
        $self->add_course_info($ref);
    }
    #
    return $ref;
}

#---------------------------------------------------------------------
#■会員識別IDと開始日時と終了日時から予約したいレッスンがダブル・ブッキングしているかどうかをチェック
#---------------------------------------------------------------------
#[引数]
#  1:会員識別ID
#  2:開始日時（YYYYMMDDhhmm）
#  3:終了日時（YYYYMMDDhhmm）
#[戻り値]
#  hashrefを返す
#---------------------------------------------------------------------
sub is_double_booking {
    my ( $self, $member_id, $stime, $etime ) = @_;
    if ( !$member_id || $member_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }
    if ( $stime !~ /^\d{12}$/ ) {
        croak "a parameter is invalid.";
    }
    if ( $etime !~ /^\d{12}$/ ) {
        croak "a parameter is invalid.";
    }
    #
    my ( $sY, $sM, $sD, $sh, $sm ) = $stime =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
    $stime = "${sY}-${sM}-${sD} ${sh}:${sm}:00";
    my ( $eY, $eM, $eD, $eh, $em ) = $etime =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
    $etime = "${eY}-${eM}-${eD} ${eh}:${em}:00";

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SELECT
    $stime = $dbh->quote($stime);
    $etime = $dbh->quote($etime);
    my $sql = "SELECT * FROM lessons WHERE member_id=${member_id} AND lsn_cancel=0";
    $sql .= " AND NOT( lsn_stime>=${etime} || lsn_etime<=${stime} )";
    my $ref = $dbh->selectrow_hashref($sql);
    if ($ref) {
        $self->add_datetime_info($ref);
        $self->add_prof_info($ref);
        $self->add_course_info($ref);
    }
    #
    return $ref;
}

#---------------------------------------------------------------------
#■レッスン登録
#---------------------------------------------------------------------
#[引数]
#  1: レッスン情報を格納した hashref
#  2: 該当のスケジュール枠の ID を格納した arrayref
#[戻り値]
#  登録した hashref
#---------------------------------------------------------------------
sub add {
    my ( $self, $ref, $sch_id_list ) = @_;

    if ( ref($sch_id_list) ne "ARRAY" || scalar( @{$sch_id_list} ) == 0 ) {
        croak "No `sch_id` was found.";
    }


    my $q = new CGI;
  	my $course_group_flag = $q->param('course_group_flag');

    #DB接続
    my $dbh = $self->{db}->connect_db();
    #
    my $rec = {};
    while ( my ( $k, $v ) = each %{$ref} ) {
        unless ( exists $self->{table_cols}->{$k} ) { next; }
        if ( defined $v ) {
            $rec->{$k} = $v;
        }
        else {
            $rec->{$k} = "";
        }
    }
    my $now = time;
    $rec->{lsn_cdate}       = $now;
    $rec->{lsn_status_date} = $now;

    $rec->{lsn_prof_repo_date}   = 0;
    $rec->{lsn_member_repo_date} = 0;
    $rec->{lsn_prof_repo_note}   = "";
    $rec->{lsn_member_repo_note} = "";
    $rec->{lsn_prof_margin}      = 0;
    $rec->{lsn_seller_margin}    = 0;

    #SQL生成
    my @klist;
    my @vlist;
    while ( my ( $k, $v ) = each %{$rec} ) {
        push( @klist, $k );
        my $q_v;
        if ( $v eq "" ) {

            #$q_v = "NULL";
            $q_v = "''";
        }
        else {
            $q_v = $dbh->quote($v);
        }
        push( @vlist, $q_v );
    }

    #INSERT
    my $lsn_id;
    my $last_sql;
    #$last_sql = "INSERT INTO lessons (" . join( ",", @klist ) . ") VALUES (" . join( ",", @vlist ) . ")";
    #print "Content-type: text/html\n\n$last_sql.\n"; exit(1);
    eval {
        $last_sql = "INSERT INTO lessons (" . join( ",", @klist ) . ") VALUES (" . join( ",", @vlist ) . ")";
        #print "Content-type: text/html\n\n$last_sql.\n"; exit(1);
        $dbh->do($last_sql);
        $lsn_id = $dbh->{mysql_insertid};
        for my $sch_id ( @{$sch_id_list} ) {

            #20201228
            if($course_group_flag == 1){
              #グループレッスン
              $last_sql = "UPDATE schedules SET group_count = group_count - 1 WHERE sch_id=${sch_id}";
            }else{
              #マンツーマン
              $last_sql = "UPDATE schedules SET lsn_id=${lsn_id} WHERE sch_id=${sch_id}";
            }
            $dbh->do($last_sql);
        }
        $self->{db}->{dbh}->commit();
    };
    if ($@) {
        $self->{db}->{dbh}->rollback();
        my $msg = "failed to insert a record to lessons table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #レッスン情報を取得
    my $lsn = $self->get($lsn_id);
    #
    return $lsn;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#  1.識別ID（必須）
#[戻り値]
#  成功すれば削除データのhashrefを返す。
#  もし存在しないlsn_idが指定されたら、未定義値を返す
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
    my ( $self, $lsn_id ) = @_;

    #識別IDのチェック
    if ( !defined $lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "the value of lsn_id in parameters is invalid.";
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #データ情報を取得
    my $lsn = $self->get($lsn_id);

    #Delete
    my $deleted;
    my $last_sql;
    eval {
        $last_sql = "DELETE FROM lessons WHERE lsn_id=${lsn_id}";
        $deleted  = $dbh->do($last_sql);
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to delete a record in lessons table.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }

    #対象のレコードがなければundefを返す
    if ( $deleted == 0 ) {
        return undef;
    }
    #
    return $lsn;
}

#---------------------------------------------------------------------
#■DBレコードを検索してCSV形式で返す
#---------------------------------------------------------------------
#[引数]
#  1.検索パラメータを格納したhashref（必須ではない）
#    {
#      lsn_id => スケジュール識別ID,
#      prof_id => 講師識別ID,
#      member_id => 会員識別ID,
#      seller_id => 代理店識別ID,
#      course_id => 授業識別ID,
#      pdm_id => 講師請求識別ID,
#      lsn_status => ステータス,
#      lsn_cancel => "通常キャンセルフラグ",
#      lsn_status_date_s => 検索開始日（YYYYMMDD）ステータス確定日を基準
#      lsn_status_date_e => 検索終了日（YYYYMMDD）ステータス確定日を基準
#      lsn_stime_s => レッスン開始日時の検索開始日時（YYYYMMDD or YYYYMMDDhhmm）
#      lsn_stime_e => レッスン開始日時の検索終了日時（YYYYMMDD or YYYYMMDDhhmm）
#      lsn_etime_s => レッスン終了日時の検索開始日時（YYYYMMDD or YYYYMMDDhhmm）
#      lsn_etime_e => レッスン終了日時の検索終了日時（YYYYMMDD or YYYYMMDDhhmm）
#      sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#      charcode => 文字コード（utf8, sjis, euc-jpのいずれか。デフォルトはsjis）,
#      returncode => 改行コード（指定がなければLF）
#    }
#    上記パラメータに指定がなかった場合のでフォルト値
#    {
#      sort =>[ ['lsn_stime', "DESC"] ]
#    }
#
#[戻り値]
#  検索結果を格納したhashref
#    {
#      tsv => CSVデータ,
#      length => CSVデータのサイズ（バイト）
#    }
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub get_csv {
    my ( $self, $in_params ) = @_;
    if ( defined $in_params && ref($in_params) ne "HASH" ) {
        croak "the 1st argument is invaiid.";
    }

    #指定の検索条件を新たなhashrefに格納
    my $params = {};
    my @param_key_list =
      ( 'lsn_id', 'prof_id', 'member_id', 'seller_id', 'course_id', 'pdm_id', 'lsn_status', 'lsn_cancel', 'lsn_status_date_s', 'lsn_status_date_e', 'lsn_stime_s', 'lsn_stime_e', 'lsn_etime_s', 'lsn_etime_e', 'sort', 'charcode', 'returncode' );
    if ( defined $in_params ) {
        for my $k (@param_key_list) {
            if ( defined $in_params->{$k} && $in_params->{$k} ne "" ) {
                $params->{$k} = $in_params->{$k};
            }
        }
    }

    #検索条件にデフォルト値をセット
    my $defaults = { sort => [ [ 'lsn_stime', "ASC" ] ] };
    while ( my ( $k, $v ) = each %{$defaults} ) {
        if ( !defined $params->{$k} && defined $v ) {
            $params->{$k} = $v;
        }
    }

    #検索条件のチェック
    while ( my ( $k, $v ) = each %{$params} ) {
        if ( $k =~ /^(lsn|sch|prof|member|seller|course|pdm)_id$/ ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "lsn_status" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "lsn_cancel" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k =~ /^lsn_status_date_[se]$/ ) {
            if ( $v !~ /^\d{8}$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
        }
        elsif ( $k =~ /^lsn_[se]time_[se]$/ ) {
            if ( $v !~ /^\d{8}$/ && $v !~ /^\d{12}$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
        }
        elsif ( $k eq "sort" ) {
            if ( ref($v) ne "ARRAY" ) {
                croak "the value of sort in parameters is invalid.";
            }
            for my $ary ( @{$v} ) {
                if ( ref($ary) ne "ARRAY" ) { croak "the value of sort in parameters is invalid."; }
                my $key   = $ary->[0];
                my $order = $ary->[1];
                if ( $key !~ /^(lsn_id|lsn_stime|lsn_status_date)$/ ) { croak "the value of sort in parameters is invalid."; }
                if ( $order !~ /^(ASC|DESC)$/ ) { croak "the value of sort in parameters is invalid."; }
            }
        }
    }
    #
    if ( defined $params->{charcode} ) {
        if ( $params->{charcode} !~ /^(utf8|sjis|euc\-jp)$/ ) {
            croak "the value of charcode is invalid.";
        }
    }
    else {
        $params->{charcode} = "sjis";
    }
    if ( defined $params->{returncode} ) {
        if ( $params->{returncode} !~ /^(\x0d\x0a|\x0d|\x0a)$/ ) {
            croak "the value of returncode is invalid.";
        }
    }
    else {
        $params->{returncode} = "\x0a";
    }

    #カラムの一覧
    my @col_list;
    my @col_name_list;
    for ( my $i = 0 ; $i < @{ $self->{csv_cols} } ; $i++ ) {
        my $r = $self->{csv_cols}->[$i];
        push( @col_list,      $r->[0] );
        push( @col_name_list, $r->[1] );
    }

    #ヘッダー行
    my $head_line = $self->make_csv_line( \@col_name_list );
    if ( $params->{charcode} ne "utf8" ) {
        $head_line = Unicode::Japanese->new( $head_line, "utf8" )->conv( $params->{charcode} );
    }
    my $csv = $head_line . $params->{returncode};

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQLのWHERE句
    my @wheres;
    if ( defined $params->{lsn_id} ) {
        push( @wheres, "lessons.lsn_id=$params->{lsn_id}" );
    }
    if ( defined $params->{prof_id} ) {
        push( @wheres, "lessons.prof_id=$params->{prof_id}" );
    }
    if ( defined $params->{member_id} ) {
        push( @wheres, "lessons.member_id=$params->{member_id}" );
    }
    if ( defined $params->{seller_id} ) {
        push( @wheres, "lessons.seller_id=$params->{seller_id}" );
    }
    if ( defined $params->{course_id} ) {
        push( @wheres, "lessons.course_id=$params->{course_id}" );
    }
    if ( defined $params->{pdm_id} ) {
        push( @wheres, "lessons.pdm_id=$params->{pdm_id}" );
    }
    if ( defined $params->{lsn_status_date_s} ) {
        my ( $Y, $M, $D ) = $params->{lsn_status_date_s} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $epoch = FCC::Class::Date::Utils->new( iso => "${Y}-${M}-${D} 00:00:00", tz => $self->{conf}->{tz} )->epoch();
        push( @wheres, "lessons.lsn_status_date >= ${epoch}" );
    }
    if ( defined $params->{lsn_status_date_e} ) {
        my ( $Y, $M, $D ) = $params->{lsn_status_date_e} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $epoch = FCC::Class::Date::Utils->new( iso => "${Y}-${M}-${D} 23:59:59", tz => $self->{conf}->{tz} )->epoch();
        push( @wheres, "lessons.lsn_status_date <= ${epoch}" );
    }
    if ( defined $params->{lsn_stime_s} ) {
        my ( $Y, $M, $D ) = $params->{lsn_stime_s} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "00";
        my $m = "00";
        if ( $params->{lsn_stime_s} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:00");
        push( @wheres, "lessons.lsn_stime >= ${qv}" );
    }
    if ( defined $params->{lsn_stime_e} ) {
        my ( $Y, $M, $D ) = $params->{lsn_stime_e} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "23";
        my $m = "59";
        if ( $params->{lsn_stime_e} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:59");
        push( @wheres, "lessons.lsn_stime <= ${qv}" );
    }

    if ( defined $params->{lsn_etime_s} ) {
        my ( $Y, $M, $D ) = $params->{lsn_etime_s} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "00";
        my $m = "00";
        if ( $params->{lsn_etime_s} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:00");
        push( @wheres, "lessons.lsn_etime >= ${qv}" );
    }
    if ( defined $params->{lsn_etime_e} ) {
        my ( $Y, $M, $D ) = $params->{lsn_etime_e} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "23";
        my $m = "59";
        if ( $params->{lsn_etime_e} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:59");
        push( @wheres, "lessons.lsn_etime <= ${qv}" );
    }
    if ( defined $params->{lsn_status} ) {
        push( @wheres, "lessons.lsn_status=$params->{lsn_status}" );
    }
    if ( defined $params->{lsn_cancel} ) {
        push( @wheres, "lessons.lsn_cancel=$params->{lsn_cancel}" );
    }

    #SELECT
    my @list;
    {
        my $sql = "SELECT " . join( ",", @col_list ) . " FROM lessons";
        $sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
        $sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
        $sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
        if (@wheres) {
            my $where = join( " AND ", @wheres );
            $sql .= " WHERE ${where}";
        }
        if ( defined $params->{sort} && @{ $params->{sort} } > 0 ) {
            my @pairs;
            for my $ary ( @{ $params->{sort} } ) {
                push( @pairs, "lessons.$ary->[0] $ary->[1]" );
            }
            $sql .= " ORDER BY " . join( ",", @pairs );
        }
        #
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        while ( my $ref = $sth->fetchrow_arrayref ) {
            for ( my $i = 0 ; $i < @{$ref} ; $i++ ) {
                my $v = $ref->[$i];
                if ( !defined $v ) {
                    $ref->[$i] = "";
                }
                if ( $self->{csv_cols}->[$i]->[2] && $ref->[$i] ) {
                    my @tm = FCC::Class::Date::Utils->new( time => $ref->[$i], tz => $self->{conf}->{tz} )->get(1);
                    $ref->[$i] = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
                }
                elsif ( $self->{csv_cols}->[$i]->[3] && $ref->[$i] ne "" ) {
                    my $cap = $self->{csv_cols}->[$i]->[3]->{ $ref->[$i] };
                    if ($cap) {
                        $ref->[$i] = $cap;
                    }
                }
            }
            my $line = $self->make_csv_line($ref);
            $line =~ s/(\x0d|\x0a)//g;
            if ( $params->{charcode} ne "utf8" ) {
                $line = Unicode::Japanese->new( $line, "utf8" )->conv( $params->{charcode} );
            }
            $csv .= "${line}$params->{returncode}";
        }
        $sth->finish();
    }
    #
    my $res = {};
    $res->{csv}    = $csv;
    $res->{length} = length $csv;
    #
    return $res;
}

sub make_csv_line {
    my ( $self, $ary ) = @_;
    my @cols;
    for my $elm ( @{$ary} ) {
        my $v = $elm;
        $v =~ s/\"/\"\"/g;
        $v = '"' . $v . '"';
        push( @cols, $v );
    }
    my $line = join( ",", @cols );
    return $line;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#  1.検索パラメータを格納したhashref（必須ではない）
#    {
#      lsn_id => スケジュール識別ID,
#      prof_id => 講師識別ID,
#      member_id => 会員識別ID,
#      seller_id => 代理店識別ID,
#      course_id => 授業識別ID,
#      pdm_id => 講師請求識別ID,
#      lsn_status => ステータス,
#      lsn_cancel => "通常キャンセルフラグ",
#      lsn_status_date_s => 検索開始日（YYYYMMDD）ステータス確定日を基準
#      lsn_status_date_e => 検索終了日（YYYYMMDD）ステータス確定日を基準
#      lsn_stime_s => レッスン開始日時の検索開始日時（YYYYMMDD or YYYYMMDDhhmm）
#      lsn_stime_e => レッスン開始日時の検索終了日時（YYYYMMDD or YYYYMMDDhhmm）
#      lsn_etime_s => レッスン終了日時の検索開始日時（YYYYMMDD or YYYYMMDDhhmm）
#      lsn_etime_e => レッスン終了日時の検索終了日時（YYYYMMDD or YYYYMMDDhhmm）
#      offset => オフセット値（デフォルト値：0）,
#      limit => リミット値（デフォルト値：20）,
#      sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#    }
#    上記パラメータに指定がなかった場合のでフォルト値
#    {
#      offset => 0,
#      limit => 20,
#      sort =>[ ['lsn_stime', "ASC"] ]
#    }
#
#[戻り値]
#  検索結果を格納したhashref
#    {
#      list => 各レコードを格納したhashrefのarrayref,
#      hit => 検索ヒット数,
#      fetch => フェッチしたレコード数,
#      start => 取り出したレコードの開始番号（offset+1, ただしhit=0の場合はstartも0となる）,
#      end => 取り出したレコードの終了番号（offset+fetch, ただしhit=0の場合はendも0となる）,
#      params => 検索条件を格納したhashref
#    }
#  失敗すればcroakする。
#---------------------------------------------------------------------
sub get_list {
    my ( $self, $in_params ) = @_;
    if ( defined $in_params && ref($in_params) ne "HASH" ) {
        croak "the 1st argument is invaiid.";
    }

    #指定の検索条件を新たなhashrefに格納
    my $params         = {};
    my @param_key_list = ( 'lsn_id', 'prof_id', 'member_id', 'seller_id', 'course_id', 'pdm_id', 'lsn_status', 'lsn_cancel', 'lsn_status_date_s', 'lsn_status_date_e', 'lsn_stime_s', 'lsn_stime_e', 'lsn_etime_s', 'lsn_etime_e', 'offset', 'limit', 'sort', );
    if ( defined $in_params ) {
        for my $k (@param_key_list) {
            if ( defined $in_params->{$k} && $in_params->{$k} ne "" ) {
                $params->{$k} = $in_params->{$k};
            }
        }
    }

    #検索条件にデフォルト値をセット
    my $defaults = {
        offset => 0,
        limit  => 20,
        sort   => [ [ 'lsn_stime', "ASC" ] ]
    };
    while ( my ( $k, $v ) = each %{$defaults} ) {
        if ( !defined $params->{$k} && defined $v ) {
            $params->{$k} = $v;
        }
    }

    #検索条件のチェック
    while ( my ( $k, $v ) = each %{$params} ) {
        if ( $k =~ /^(lsn|sch|prof|member|seller|course|pdm)_id$/ ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "lsn_status" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k eq "lsn_cancel" ) {
            if ( $v =~ /[^\d]/ ) {
                delete $params->{$k};
            }
            else {
                $params->{$k} = $v + 0;
            }
        }
        elsif ( $k =~ /^lsn_status_date_[se]$/ ) {
            if ( $v !~ /^\d{8}$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
        }
        elsif ( $k =~ /^lsn_[se]time_[se]$/ ) {
            if ( $v !~ /^\d{8}$/ && $v !~ /^\d{12}$/ ) {
                croak "the value of ${k} in parameters is invalid.";
            }
        }
        elsif ( $k eq "offset" ) {
            if ( $v =~ /[^\d]/ ) {
                croak "the value of offset in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "limit" ) {
            if ( $v =~ /[^\d]/ ) {
                croak "the value of limit in parameters is invalid.";
            }
            $params->{$k} = $v + 0;
        }
        elsif ( $k eq "sort" ) {
            if ( ref($v) ne "ARRAY" ) {
                croak "the value of sort in parameters is invalid.";
            }
            for my $ary ( @{$v} ) {
                if ( ref($ary) ne "ARRAY" ) { croak "the value of sort in parameters is invalid."; }
                my $key   = $ary->[0];
                my $order = $ary->[1];
                if ( $key !~ /^(lsn_id|lsn_stime|lsn_status_date)$/ ) { croak "the value of sort in parameters is invalid."; }
                if ( $order !~ /^(ASC|DESC)$/ ) { croak "the value of sort in parameters is invalid."; }
            }
        }
    }

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #SQLのWHERE句
    my @wheres;
    if ( defined $params->{lsn_id} ) {
        push( @wheres, "lessons.lsn_id=$params->{lsn_id}" );
    }
    if ( defined $params->{prof_id} ) {
        push( @wheres, "lessons.prof_id=$params->{prof_id}" );
    }
    if ( defined $params->{member_id} ) {
        push( @wheres, "lessons.member_id=$params->{member_id}" );
    }
    if ( defined $params->{seller_id} ) {
        push( @wheres, "lessons.seller_id=$params->{seller_id}" );
    }
    if ( defined $params->{course_id} ) {
        push( @wheres, "lessons.course_id=$params->{course_id}" );
    }
    if ( defined $params->{pdm_id} ) {
        push( @wheres, "lessons.pdm_id=$params->{pdm_id}" );
    }
    if ( defined $params->{lsn_status_date_s} ) {
        my ( $Y, $M, $D ) = $params->{lsn_status_date_s} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $epoch = FCC::Class::Date::Utils->new( iso => "${Y}-${M}-${D} 00:00:00", tz => $self->{conf}->{tz} )->epoch();
        push( @wheres, "lessons.lsn_status_date >= ${epoch}" );
    }
    if ( defined $params->{lsn_status_date_e} ) {
        my ( $Y, $M, $D ) = $params->{lsn_status_date_e} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $epoch = FCC::Class::Date::Utils->new( iso => "${Y}-${M}-${D} 23:59:59", tz => $self->{conf}->{tz} )->epoch();
        push( @wheres, "lessons.lsn_status_date <= ${epoch}" );
    }
    if ( defined $params->{lsn_stime_s} ) {
        my ( $Y, $M, $D ) = $params->{lsn_stime_s} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "00";
        my $m = "00";
        if ( $params->{lsn_stime_s} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:00");
        push( @wheres, "lessons.lsn_stime >= ${qv}" );
    }
    if ( defined $params->{lsn_stime_e} ) {
        my ( $Y, $M, $D ) = $params->{lsn_stime_e} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "23";
        my $m = "59";
        if ( $params->{lsn_stime_e} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:59");
        push( @wheres, "lessons.lsn_stime <= ${qv}" );
    }

    if ( defined $params->{lsn_etime_s} ) {
        my ( $Y, $M, $D ) = $params->{lsn_etime_s} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "00";
        my $m = "00";
        if ( $params->{lsn_etime_s} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:00");
        push( @wheres, "lessons.lsn_etime >= ${qv}" );
    }
    if ( defined $params->{lsn_etime_e} ) {
        my ( $Y, $M, $D ) = $params->{lsn_etime_e} =~ /^(\d{4})(\d{2})(\d{2})/;
        my $h = "23";
        my $m = "59";
        if ( $params->{lsn_etime_e} =~ /^\d{8}(\d{2})(\d{2})/ ) {
            $h = $1;
            $m = $2;
        }
        my $qv = $dbh->quote("${Y}-${M}-${D} ${h}:${m}:59");
        push( @wheres, "lessons.lsn_etime <= ${qv}" );
    }
    if ( defined $params->{lsn_status} ) {
        push( @wheres, "lessons.lsn_status=$params->{lsn_status}" );
    }
    if ( defined $params->{lsn_cancel} ) {
        push( @wheres, "lessons.lsn_cancel=$params->{lsn_cancel}" );
    }

    #レコード数
    my $hit = 0;
    {
        my $sql = "SELECT COUNT(lessons.lsn_id) FROM lessons";
        if (@wheres) {
            $sql .= " WHERE ";
            $sql .= join( " AND ", @wheres );
        }
        ($hit) = $dbh->selectrow_array($sql);
    }
    $hit += 0;

    #SELECT
    my @list;
    {
        my $sql = "SELECT lessons.*, profs.*, courses.* FROM lessons";
        $sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
        $sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
        if (@wheres) {
            my $where = join( " AND ", @wheres );
            $sql .= " WHERE ${where}";
        }
        if ( defined $params->{sort} && @{ $params->{sort} } > 0 ) {
            my @pairs;
            for my $ary ( @{ $params->{sort} } ) {
                push( @pairs, "lessons.$ary->[0] $ary->[1]" );
            }
            $sql .= " ORDER BY " . join( ",", @pairs );
        }
        $sql .= " LIMIT $params->{offset}, $params->{limit}";
        #
        my $sth = $dbh->prepare($sql);
        $sth->execute();
        while ( my $ref = $sth->fetchrow_hashref ) {
            $self->add_datetime_info($ref);
            $self->add_prof_info($ref);
            $self->add_course_info($ref);
            push( @list, $ref );
        }
        $sth->finish();
    }
    #
    my $res = {};
    $res->{list}  = \@list;
    $res->{hit}   = $hit;
    $res->{fetch} = scalar @list;
    $res->{start} = 0;
    if ( $res->{fetch} > 0 ) {
        $res->{start} = $params->{offset} + 1;
        $res->{end}   = $params->{offset} + $res->{fetch};
    }
    $res->{params} = $params;
    #
    return $res;
}

sub add_prof_info {
    my ( $self, $ref ) = @_;
    $ref->{prof_country_name}   = $self->{prof_country_hash}->{ $ref->{prof_country} };
    $ref->{prof_residence_name} = $self->{prof_country_hash}->{ $ref->{prof_residence} };
    my $prof_id = $ref->{prof_id};
    for ( my $s = 1 ; $s <= 3 ; $s++ ) {
        $ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
        $ref->{"prof_logo_${s}_w"}   = $self->{conf}->{"prof_logo_${s}_w"};
        $ref->{"prof_logo_${s}_h"}   = $self->{conf}->{"prof_logo_${s}_h"};
    }
}

sub add_course_info {
    my ( $self, $ref ) = @_;
    my $course_id = $ref->{course_id};
    for ( my $s = 1 ; $s <= 3 ; $s++ ) {
        $ref->{"course_logo_${s}_url"} = "$self->{conf}->{course_logo_dir_url}/${course_id}.${s}.$self->{conf}->{course_logo_ext}";
        $ref->{"course_logo_${s}_w"}   = $self->{conf}->{"course_logo_${s}_w"};
        $ref->{"course_logo_${s}_h"}   = $self->{conf}->{"course_logo_${s}_h"};
    }
}

sub add_datetime_info {
    my ( $self, $ref ) = @_;
    my ( $sY, $sM, $sD, $sh, $sm ) = $ref->{lsn_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
    my ( $eY, $eM, $eD, $eh, $em ) = $ref->{lsn_etime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
    $ref->{stime} = ( $sh + 0 ) . ":" . $sm;
    $ref->{etime} = ( $eh + 0 ) . ":" . $em;

    #レッスン開始日時
    my $stime_epoch = FCC::Class::Date::Utils->new( iso => "${sY}-${sM}-${sD} ${sh}:${sm}:00", tz => $self->{conf}->{tz} )->epoch();
    my %stime_fmt = FCC::Class::Date::Utils->new( time => $stime_epoch, tz => $self->{conf}->{tz} )->get_formated();
    while ( my ( $k, $v ) = each %stime_fmt ) {
        $ref->{"lsn_stime_${k}"} = $v;
    }

    #レッスン修了日時
    my $etime_epoch = FCC::Class::Date::Utils->new( iso => "${eY}-${eM}-${eD} ${eh}:${em}:00", tz => $self->{conf}->{tz} )->epoch();
    my %etime_fmt = FCC::Class::Date::Utils->new( time => $etime_epoch, tz => $self->{conf}->{tz} )->get_formated();
    while ( my ( $k, $v ) = each %etime_fmt ) {
        $ref->{"lsn_etime_${k}"} = $v;
    }

    #完了報告有効期限日時
    my $report_limit_epoch = $etime_epoch + ( $self->{conf}->{lesson_report_limit} * 60 );
    my %report_limit_fmt   = FCC::Class::Date::Utils->new( time => $report_limit_epoch, tz => $self->{conf}->{tz} )->get_formated();
    while ( my ( $k, $v ) = each %report_limit_fmt ) {
        $ref->{"lsn_report_limit_${k}"} = $v;
    }

    #今が完了報告可能な日時か
    $ref->{lsn_report_available} = 0;

    #	if( $self->{now} > $etime_epoch && $self->{now} <= $report_limit_epoch ) {
    if ( $self->{now} > $stime_epoch && $self->{now} <= $report_limit_epoch ) {
        $ref->{lsn_report_available} = 1;
    }

    #キャンセル可能かどうか
    $ref->{lsn_cancelable} = 0;
    my $now = $self->{nowYMDhm} . "00";
    if ( $ref->{lsn_prof_repo} == 0 && $ref->{lsn_member_repo} == 0 && $self->{nowYMDhm} lt "${sY}${sM}${sD}${sh}${sm}" ) {
        $ref->{lsn_pay_fee_rate} = $self->{conf}->{normal_point_fee_rate};
        my $lsn_base_price            = int( $ref->{lsn_prof_fee} * $ref->{lsn_pay_fee_rate} / 100 );
        my $normal_cancel_limit_epoch = $stime_epoch - ( $self->{conf}->{cancelable_hours} * 3600 );
        my @dt                        = FCC::Class::Date::Utils->new( time => $normal_cancel_limit_epoch, tz => $self->{conf}->{tz} )->get(1);
        if ( $self->{nowYMDhm} lt "$dt[0]$dt[1]$dt[2]$dt[3]$dt[4]" ) {

            #通常キャンセル
            $ref->{lsn_cancelable} = 1;
            if ( $ref->{lsn_pay_type} == 1 ) {
                $ref->{lsn_pay_fee_rate} = $self->{conf}->{cancel1_point_fee_rate};
            }
            else {
                $ref->{lsn_pay_fee_rate} = $self->{conf}->{cancel1_coupon_fee_rate};
            }
        }
        else {
            #緊急キャンセル
            $ref->{lsn_cancelable} = 2;
            if ( $ref->{lsn_pay_type} == 1 ) {
                $ref->{lsn_pay_fee_rate} = $self->{conf}->{cancel2_point_fee_rate};
            }
            else {
                $ref->{lsn_pay_fee_rate} = $self->{conf}->{cancel2_coupon_fee_rate};
            }
        }

        #課金する金額
        unless ( $ref->{lsn_base_price} ) {
            $ref->{lsn_base_price} = int( $ref->{lsn_prof_fee} * $ref->{lsn_pay_fee_rate} / 100 );
        }
    }

    #管理者側でレッスン・ステータスを変更可能かどうか
    my $lesson_bill_limit_epoch = $etime_epoch + ( $self->{conf}->{lesson_bill_limit} * 60 );
    $ref->{lsn_status_settable} = 0;

    #	if( $ref->{lsn_charged_date} == 0 && $self->{now} > $report_limit_epoch && $self->{now} <= $lesson_bill_limit_epoch ) {
    if ( $ref->{lsn_charged_date} == 0 && ( $self->{now} > $report_limit_epoch || ( $ref->{lsn_member_repo} && $ref->{lsn_prof_repo} ) ) ) {
        $ref->{lsn_status_settable} = 1;
    }
    #
    $ref->{lsn_today} = "";
    if ( $self->{nowYMDhm} =~ /^${sY}${sM}${sD}/ && $self->{nowYMDhm} lt "${sY}${sM}${sD}${sh}${sm}" ) {
        $ref->{lsn_today} = "today";
    }
    #
    $ref->{lsn_during} = "";
    if ( $self->{nowYMDhm} ge "${sY}${sM}${sD}${sh}${sm}" && $self->{nowYMDhm} lt "${eY}${eM}${eD}${eh}${em}" ) {
        $ref->{lsn_during} = "during";
    }
    #
    $ref->{lsn_finished} = "";
    $ref->{finished}     = "";
    if ( $self->{nowYMDhm} gt "${eY}${eM}${eD}${eh}${em}" ) {
        $ref->{lsn_finished} = "finished";
        $ref->{finished}     = "finished";
    }
}

#----------------------------------------------------------
#■払い戻し処理
#・lessonsテーブルの該当レコードのlsn_base_priceが0ならボタンを表示しない
#  ・売上げが確定していない、または、すでに払い戻し処理が終わっている場合が該当
#・lessonsテーブルの該当レコードの以下のカラムの値を更新する
#  ・lsn_base_price=0
#  ・lsn_prof_price=0
#  ・lsn_seller_price=0
#  ・lsn_status=29 (その他の理由による非課金)
#・membersテーブルの該当の会員レコードの以下のレコードを操作する
#  ・member_pointまたはmember_couponに、lessonsテーブルのlsn_base_price分だけを加算する
#  ・ポイントかクーポンかは、lessonsテーブルのレコードのlsn_pay_typeで判定
#・ポイントであれば、mbractsテーブルに加算のレコードを追加
#  ・mbract_reasonは「13:入金（キャンセルによる払い戻し）」とする
#・クーポンであれば、cpnactsテーブルに加算のレコードを追加
#  ・mbract_reasonは「13:入金（キャンセルによる払い戻し）」とする
#
#※ポイントの有効期限は延長しない
#----------------------------------------------------------
sub pay_back {
    my ( $self, $lsn_id ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.";
    }

    #レッスン情報
    my $lsn = $self->get($lsn_id);
    unless ($lsn) {
        croak "The specified lesson was not found.";
    }
    unless ( $lsn->{lsn_base_price} > 0 ) {
        croak "The specified lesson is not allowed to be paid back.";
    }
    unless ( $lsn->{lsn_pay_type} == 1 || $lsn->{lsn_pay_type} == 2 ) {
        croak "The specified lesson is invalid.";
    }
    #
    my $member_id  = $lsn->{member_id};
    my $seller_id  = $lsn->{seller_id};
    my $base_price = $lsn->{lsn_base_price};
    my $coupon_id  = $lsn->{coupon_id};

    #DB接続
    my $dbh = $self->{db}->connect_db();

    #払い戻し処理
    my $last_sql;
    eval {
        #--------------------------------------------------------------
        #・lessonsテーブルの該当レコードの以下のカラムの値を更新する
        #　・lsn_base_price=0
        #　・lsn_prof_price=0
        #　・lsn_seller_price=0
        #　・lsn_status=31 (払い戻し)
        #--------------------------------------------------------------
        $last_sql = "UPDATE lessons SET lsn_base_price=0, lsn_prof_price=0, lsn_seller_price=0, lsn_status=31 WHERE lsn_id=${lsn_id}";
        $dbh->do($last_sql);

        #--------------------------------------------------------------
        #・membersテーブルの該当の会員レコードの以下のレコードを操作する
        #　・member_pointまたはmember_couponに、lessonsテーブルのlsn_base_price分だけを加算する
        #　・ポイントかクーポンかは、lessonsテーブルのレコードのlsn_pay_typeで判定
        #--------------------------------------------------------------
        my $cname = "";
        if ( $lsn->{lsn_pay_type} == 1 ) {    #ポイント払い
            $cname = "member_point";
        }
        elsif ( $lsn->{lsn_pay_type} == 2 ) {    #クーポン払い
            $cname = "member_coupon";
        }
        $last_sql = "UPDATE members SET ${cname}=${cname}+${base_price} WHERE member_id=${member_id}";
        $dbh->do($last_sql);

        #--------------------------------------------------------------
        #・ポイントであれば、mbractsテーブルに加算のレコードを追加
        #　・mbract_reasonは「13:入金（キャンセルによる払い戻し）」とする
        #・クーポンであれば、cpnactsテーブルに加算のレコードを追加
        #　・mbract_reasonは「13:入金（キャンセルによる払い戻し）」とする
        #--------------------------------------------------------------
        my $now       = time;
        my $act_table = "";
        my $act_rec   = {};
        if ( $lsn->{lsn_pay_type} == 1 ) {    #ポイント払い
            $act_table = "mbracts";
            $act_rec   = {
                member_id     => $member_id,
                seller_id     => $seller_id,
                mbract_type   => 1,
                mbract_reason => 13,
                mbract_cdate  => $now,
                mbract_price  => $base_price,
                lsn_id        => $lsn_id
            };
        }
        elsif ( $lsn->{lsn_pay_type} == 2 ) {    #クーポン払い
            $act_table = "cpnacts";
            $act_rec   = {
                coupon_id     => $coupon_id,
                member_id     => $member_id,
                seller_id     => $seller_id,
                cpnact_type   => 1,
                cpnact_reason => 13,
                cpnact_cdate  => $now,
                cpnact_price  => $base_price,
                lsn_id        => $lsn_id
            };
        }
        my @klist;
        my @vlist;
        while ( my ( $k, $v ) = each %{$act_rec} ) {
            push( @klist, $k );
            push( @vlist, $v );
        }
        my $last_sql = "INSERT INTO " . ${act_table} . " (" . join( ",", @klist ) . ") VALUES (" . join( ",", @vlist ) . ")";
        $dbh->do($last_sql);

        #--------------------------------------------------------------
        $dbh->commit();
    };
    if ($@) {
        $dbh->rollback();
        my $msg = "failed to pay back.";
        FCC::Class::Log->new( conf => $self->{conf} )->loging( "error", "${msg} : $@ : ${last_sql}" );
        croak $msg;
    }
    #
    my $new_lsn = $self->get($lsn_id);
    return $new_lsn;
}

#---------------------------------------------------------------------
#■授業を更新
#---------------------------------------------------------------------
#[引数]
#  1:レッスン識別ID
#  2:授業コード
#  3:該当レッスンのhashref（必須ではないが、指定するとパフォーマンスがよい）
#[戻り値]
#  該当のレッスンのhashref
#---------------------------------------------------------------------
sub update_course {
    my ( $self, $lsn_id, $course_id, $lsn ) = @_;
    if ( !$lsn_id || $lsn_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.(1)";
    }
    if ( !$course_id || $course_id =~ /[^\d]/ ) {
        croak "a parameter is invalid.(2)";
    }
    if ( $lsn && ( ref($lsn) ne "HASH" || $lsn->{lsn_id} != $lsn_id ) ) {
        croak "a parameter is invalid.(3)";
    }
    unless ($lsn) {
        $lsn = $self->get($lsn_id);
        unless ($lsn) {
            croak "a parameter is invalid.(4)";
        }
    }
    #
    my $rec = {
        lsn_id            => $lsn_id,
        course_id         => $course_id
    };

    #アップデート
    my $new_lsn = $self->mod($rec);
    return $new_lsn;
}


#---------------------------------------------------------------------
#■コースIDからスケジュール日付のリストを取得（プレビュー用）
#---------------------------------------------------------------------
sub get_course_schedule_preview {
    my ($self, $course_id) = @_;
    
    my $dbh = $self->{db}->connect_db();
    my $sql_course = "SELECT * FROM courses WHERE course_id = " . $dbh->quote($course_id);
    my $course = $dbh->selectrow_hashref($sql_course);

    return undef unless $course;

    my @schedule_dates;
    my $t_date;
    
    eval {
        $t_date = Time::Piece->strptime($course->{course_start_date}, '%Y-%m-%d');
    };
    if ($@) { return undef; }

    # 休講日集合（YYYY-MM-DD のリストをハッシュに）
    my %holidays;
    if ( defined $course->{course_holiday_dates} && $course->{course_holiday_dates} ne "" ) {
        for my $line ( split( /\r\n|\r|\n|,/, $course->{course_holiday_dates} ) ) {
            $line =~ s/^\s+|\s+$//g;
            $holidays{$line} = 1 if $line =~ /^\d{4}-\d{2}-\d{2}$/;
        }
    }

    my $found_count = 0;
    my $safety_loop = 0;
    my $max_loop = 365 * 3;

    while ($found_count < $course->{course_total_lessons}) {
        last if $safety_loop++ > $max_loop;

        my $ymd = $t_date->ymd;
        if ( $holidays{$ymd} ) {
            $t_date += ONE_DAY;    # 休講日はスキップして翌日へ
            next;
        }

        # 修正：wday(日曜=1) から 1 を引いて、日曜=0 に補正する
        # ※もし wday が 0 だったら 0 のままにする安全策も入れています
        my $wday_index = ($t_date->wday > 0) ? $t_date->wday - 1 : 0;
        my $current_bit = 1 << $wday_index;
        
        if ($course->{course_weekday_mask} & $current_bit) {
            push @schedule_dates, {
                date  => $t_date->ymd,
                wday  => $t_date->wdayname, 
                stime => $t_date->ymd . " " . $course->{course_time_start},
                etime => $t_date->ymd . " " . $course->{course_time_end},
            };
            $found_count++;
        }
        $t_date += ONE_DAY;
    }
    
    return {
        course => $course,
        dates  => \@schedule_dates
    };
}

sub add_bulk_from_course {
    my ($self, $course_id, $member_ids_ref) = @_;
    
    # 日程を取得
    my $preview = $self->get_course_schedule_preview($course_id);
    unless ($preview) { croak "Course ID not found or invalid dates."; }
    
    my $dates = $preview->{dates};
    my $course = $preview->{course};
    my $dbh = $self->{db}->connect_db();
    
    my $total_inserted = 0;
    my $current_epoch = time;

    # SQL修正：ratingをNULLに、noteを空文字に変更しました
    my $sql_insert = <<SQL;
INSERT INTO lessons (
    prof_id, 
    member_id, 
    seller_id, 
    course_id, 
    lsn_cdate, 
    lsn_stime, 
    lsn_etime, 
    lsn_status_date,
    lsn_cancel,
    lsn_status,
    lsn_pay_type,
    lsn_prof_repo,
    lsn_member_repo,
    lsn_prof_repo_date,
    lsn_member_repo_date,
    lsn_prof_repo_note,
    lsn_member_repo_note,
    lsn_member_repo_rating,
    lsn_review,
    lsn_review_show,
    lsn_prof_fee,
    lsn_pay_fee_rate,
    lsn_base_price,
    lsn_prof_margin,
    lsn_prof_price,
    lsn_seller_margin,
    lsn_seller_price
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, ?, 
    0, 0, 1, 
    0, 0, 
    0, 0, 
    '', '', 
    NULL, NULL, 0,
    1, 100, 1, 100, 1, 0, 0
)
SQL
    # ↑ 値の内訳:
    # lsn_pay_type = 1
    # lsn_member_repo_note = '' (空文字)
    # lsn_member_repo_rating = NULL
    # lsn_review = NULL
    # lsn_seller_price = 0
    
    my $sth = $dbh->prepare($sql_insert);

    # グループレッスンコースの場合、新テーブル group_lesson_slots / group_lesson_bookings にも登録
    if ($course->{course_group_flag}) {
        my $capacity_max = $course->{course_group_upper} && $course->{course_group_upper} > 0
            ? $course->{course_group_upper}
            : scalar(@$member_ids_ref);
        $capacity_max = scalar(@$member_ids_ref) if scalar(@$member_ids_ref) > $capacity_max;
        my $prof_id    = $course->{prof_id};
        my $course_fee = $course->{course_fee} ? int($course->{course_fee}) : 0;

        foreach my $d (@$dates) {
            my $q_st = $dbh->quote($d->{stime});
            my $q_en = $dbh->quote($d->{etime});
            my $sql_slot = "INSERT INTO group_lesson_slots (course_id, prof_id, slot_stime, slot_etime, capacity_max, capacity_current, status, cdate, mdate) VALUES ($course_id, $prof_id, $q_st, $q_en, $capacity_max, 0, 1, $current_epoch, 0)";
            $dbh->do($sql_slot);
            my $slot_id = $dbh->{mysql_insertid};

            foreach my $mem_id (@$member_ids_ref) {
                my $sql_booking = "INSERT INTO group_lesson_bookings (slot_id, member_id, seller_id, pay_type, price, coupon_id, status, cancel_reason, cdate, mdate) VALUES ($slot_id, $mem_id, 0, 1, $course_fee, 0, 1, NULL, $current_epoch, 0)";
                $dbh->do($sql_booking);
            }
            $dbh->do("UPDATE group_lesson_slots SET capacity_current = " . scalar(@$member_ids_ref) . " WHERE slot_id = $slot_id");
        }
    }

    foreach my $mem_id (@$member_ids_ref) {
        foreach my $d (@$dates) {
            # 秒(:00)は補完しない
            my $stime_full = $d->{stime};
            my $etime_full = $d->{etime};
            
            $sth->execute(
                $course->{prof_id},  # prof_id
                $mem_id,             # member_id
                0,                   # seller_id
                $course_id,          # course_id
                $current_epoch,      # lsn_cdate
                $stime_full,         # lsn_stime
                $etime_full,         # lsn_etime
                $current_epoch       # lsn_status_date
            );
            $total_inserted++;
        }
    }
    
    # コミット
    $dbh->commit();

    return $total_inserted;
}
1;