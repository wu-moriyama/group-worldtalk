package FCC::Class::Salescount;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Date::Pcalc;
use Unicode::Japanese;
use FCC::Class::Date::Utils;

sub init {
    my ( $self, %args ) = @_;
    unless ( $args{conf} && $args{db} ) {
        croak "parameters are lacking.";
    }
    $self->{conf} = $args{conf};
    $self->{db}   = $args{db};
}

#---------------------------------------------------------------------
#■クーポン管理 cpnact の「入金（会員登録）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count1 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );
    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(cpnact_price) FROM cpnacts";
    $sql .= " WHERE cpnact_reason=11";
    $sql .= " AND cpnact_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

sub check_date_range {
    my ( $self, $sdate, $edate ) = @_;

    my ( $sY, $sM, $sD ) = $sdate =~ /^(\d{4})\-(\d{2})\-(\d{2})$/;
    my ( $eY, $eM, $eD ) = $edate =~ /^(\d{4})\-(\d{2})\-(\d{2})$/;

    unless ( Date::Pcalc::check_date( $sY, $sM, $sD ) ) {
        croak "The `sdate` is invalid: ${sdate}";
    }
    unless ( Date::Pcalc::check_date( $eY, $eM, $eD ) ) {
        croak "The `edate` is invalid: ${edate}";
    }

    my $tz     = $self->{conf}->{tz};
    my $sepoch = FCC::Class::Date::Utils->new(
        iso => "${sY}-${sM}-${sD} 00:00:00",
        tz  => $tz
    )->epoch();

    my $eepoch = FCC::Class::Date::Utils->new(
        iso => "${eY}-${eM}-${eD} 23:59:59",
        tz  => $tz
    )->epoch();

    return ( $sepoch, $eepoch );
}

#---------------------------------------------------------------------
#■クーポン管理 cpnact の「入金（会員登録）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv1 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT cpnacts.cpnact_id, cpnacts.member_id,";
    $sql .= " members.member_handle, members.seller_id, cpnacts.cpnact_reason,";
    $sql .= " cpnacts.cpnact_cdate, cpnacts.cpnact_price";
    $sql .= " FROM cpnacts";
    $sql .= " LEFT JOIN members ON cpnacts.member_id=members.member_id";
    $sql .= " WHERE cpnacts.cpnact_reason=11";
    $sql .= " AND cpnacts.cpnact_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{cpnact_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{cpnact_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{cpnact_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{cpnact_price}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「出金（有効期限切れ）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count2 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(ABS(mbract_price)) FROM mbracts";
    $sql .= " WHERE mbract_reason=91";
    $sql .= " AND mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「出金（有効期限切れ）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv2 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT mbracts.mbract_id, mbracts.member_id,";
    $sql .= " members.member_handle, members.seller_id, mbracts.mbract_reason,";
    $sql .= " mbracts.mbract_cdate, ABS(mbracts.mbract_price)";
    $sql .= " FROM mbracts";
    $sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
    $sql .= " WHERE mbracts.mbract_reason=91";
    $sql .= " AND mbracts.mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{mbract_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{mbract_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{mbract_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{'ABS(mbracts.mbract_price)'}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「入金（管理者より付与）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count3 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(mbract_price) FROM mbracts";
    $sql .= " WHERE mbract_reason=12";
    $sql .= " AND mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「入金（管理者より付与）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv3 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT mbracts.mbract_id, mbracts.member_id,";
    $sql .= " members.member_handle, members.seller_id, mbracts.mbract_reason,";
    $sql .= " mbracts.mbract_cdate, ABS(mbracts.mbract_price)";
    $sql .= " FROM mbracts";
    $sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
    $sql .= " WHERE mbracts.mbract_reason=12";
    $sql .= " AND mbracts.mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{mbract_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{mbract_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{mbract_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{'ABS(mbracts.mbract_price)'}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■クーポン管理 cpnact の「出金（有効期限切れ）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count4 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(ABS(cpnact_price)) FROM cpnacts";
    $sql .= " WHERE cpnact_reason=91";
    $sql .= " AND cpnact_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■クーポン管理 cpnact の「出金（有効期限切れ）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv4 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT cpnacts.cpnact_id, cpnacts.member_id,";
    $sql .= " members.member_handle, members.seller_id, cpnacts.cpnact_reason,";
    $sql .= " cpnacts.cpnact_cdate, ABS(cpnacts.cpnact_price)";
    $sql .= " FROM cpnacts";
    $sql .= " LEFT JOIN members ON cpnacts.member_id=members.member_id";
    $sql .= " WHERE cpnacts.cpnact_reason=91";
    $sql .= " AND cpnacts.cpnact_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{cpnact_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{cpnact_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{cpnact_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{'ABS(cpnacts.cpnact_price)'}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count5 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    unless($self->is_valid_date($sdate)) {
        croak "The `sdate` is invalid: ${sdate}";
    }
    unless($self->is_valid_date($edate)) {
        croak "The `edate` is invalid: ${edate}";
    }

    my $dbh = $self->{db}->connect_db();

    my $q_sdt = $dbh->quote("${sdate} 00:00:00");
    my $q_edt = $dbh->quote("${edate} 23:59:59");

    my $sql = "SELECT SUM(lsn_prof_fee) FROM lessons";
    $sql .= " WHERE lsn_status IN (1, 12, 13)";
    $sql .= " AND lsn_stime BETWEEN ${q_sdt} AND ${q_edt}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

sub is_valid_date {
    my ( $self, $date ) = @_;
    my ( $Y, $M, $D ) = $date =~ /^(\d{4})\-(\d{2})\-(\d{2})$/;
    return Date::Pcalc::check_date( $Y, $M, $D );
}

#sub count5 {
#    my ( $self, $sdate, $edate ) = @_;
#
#    # 引数をチェック
#    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );
#
#    my $dbh = $self->{db}->connect_db();
#
#    my $sql = "SELECT SUM(lsn_prof_fee) FROM lessons";
#    $sql .= " WHERE lsn_status IN (1, 12, 13)";
#    $sql .= " AND lsn_status_date BETWEEN ${sepoch} AND ${eepoch}";
#
#    my ($sum) = $dbh->selectrow_array($sql);
#    unless ($sum) {
#        $sum = 0;
#    }
#    return $sum;
#}

#---------------------------------------------------------------------
#■レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv5 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    #my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    unless($self->is_valid_date($sdate)) {
        croak "The `sdate` is invalid: ${sdate}";
    }
    unless($self->is_valid_date($edate)) {
        croak "The `edate` is invalid: ${edate}";
    }

    my $dbh = $self->{db}->connect_db();
    my $q_sdt = $dbh->quote("${sdate} 00:00:00");
    my $q_edt = $dbh->quote("${edate} 23:59:59");


    my @header_colmns = (
        'レッスンID',   'レッスン種別',   '講師ID',     '講師名', 
        '会員ID','会員名', 'レッスン日時', '費用（pt）', 'ステータス',
        '講師報酬（税抜）',   '講師報酬（税込）'
    );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT lessons.lsn_id, lessons.prof_id, profs.prof_handle,";
    $sql .= " lessons.member_id, members.member_handle, members.seller_id,";
    $sql .= " lessons.course_id, courses.course_name,";
    $sql .= " lessons.lsn_status, lessons.lsn_stime, lessons.lsn_etime,";
    $sql .= " lessons.lsn_prof_fee, lessons.lsn_prof_price, lessons.lsn_prof_price_zei";
    $sql .= " FROM lessons";
    $sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
    $sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
    $sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
    $sql .= " WHERE lessons.lsn_status IN (1, 12, 13)";
    #$sql .= " AND lessons.lsn_status_date BETWEEN ${sepoch} AND ${eepoch}";
    $sql .= " AND lessons.lsn_stime BETWEEN ${q_sdt} AND ${q_edt}";

    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @cols = (
            $ref->{lsn_id},
            $self->quote_string( $ref->{course_name} ),
            $ref->{prof_id},
            $self->quote_string( $ref->{prof_handle} ),
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{lsn_stime},
            $ref->{lsn_prof_fee},
            $ref->{lsn_status},
            $ref->{lsn_prof_price},
            $ref->{lsn_prof_price_zei}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

sub quote_string {
    my ( $self, $str ) = @_;
    if ($str) {
        $str =~ s/\"/\"\"/g;

    }
    else {
        $str = '';
    }
    $str = '"' . $str . '"';
    return $str;
}

#---------------------------------------------------------------------
#■クーポン管理 cpnact の「入金（管理者より付与）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count6 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );
    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(cpnact_price) FROM cpnacts";
    $sql .= " WHERE cpnact_reason=12";
    $sql .= " AND cpnact_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■クーポン管理 cpnact の「入金（管理者より付与）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv6 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT cpnacts.cpnact_id, cpnacts.member_id,";
    $sql .= " members.member_handle, members.seller_id, cpnacts.cpnact_reason,";
    $sql .= " cpnacts.cpnact_cdate, cpnacts.cpnact_price";
    $sql .= " FROM cpnacts";
    $sql .= " LEFT JOIN members ON cpnacts.member_id=members.member_id";
    $sql .= " WHERE cpnacts.cpnact_reason=12";
    $sql .= " AND cpnacts.cpnact_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{cpnact_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{cpnact_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{cpnact_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{cpnact_price}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「出金（動画コースの購入）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count7 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(ABS(mbract_price)) FROM mbracts";
    $sql .= " WHERE mbract_reason=54";
    $sql .= " AND mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「出金（動画コースの購入）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv7 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT mbracts.mbract_id, mbracts.member_id,";
    $sql .= " members.member_handle, members.seller_id, mbracts.mbract_reason,";
    $sql .= " mbracts.mbract_cdate, ABS(mbracts.mbract_price)";
    $sql .= " FROM mbracts";
    $sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
    $sql .= " WHERE mbracts.mbract_reason=54";
    $sql .= " AND mbracts.mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{mbract_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{mbract_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{mbract_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{'ABS(mbracts.mbract_price)'}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「入金（銀行振込単発チケット購入）」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count8 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(mbract_price) FROM mbracts";
    $sql .= " WHERE mbract_reason=43";
    $sql .= " AND mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■ポイント管理 mbract の「入金（銀行振込単発チケット購入）」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv8 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '入出金ID', '会員ID', '会員ニックネーム', '代理店ID', '適用', '日時', '金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT mbracts.mbract_id, mbracts.member_id,";
    $sql .= " members.member_handle, members.seller_id, mbracts.mbract_reason,";
    $sql .= " mbracts.mbract_cdate, mbracts.mbract_price";
    $sql .= " FROM mbracts";
    $sql .= " LEFT JOIN members ON mbracts.member_id=members.member_id";
    $sql .= " WHERE mbracts.mbract_reason=43";
    $sql .= " AND mbracts.mbract_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{mbract_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{mbract_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{mbract_reason},
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{mbract_price}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■カード決済管理 card の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count9 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(crd_point) FROM cards";
    $sql .= " WHERE crd_success=1";
    $sql .= " AND crd_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■カード決済管理 card のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv9 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns =
      ( '決済ID', '会員ID', '会員ニックネーム', 'プラン名', '日時', 'プランポイント', 'プラン金額' );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT cards.crd_id, cards.member_id, members.member_handle,";
    $sql .=
      " plans.pln_title, cards.crd_cdate, cards.crd_point, cards.crd_price";
    $sql .= " FROM cards";
    $sql .= " LEFT JOIN members ON cards.member_id=members.member_id";
    $sql .= " LEFT JOIN plans ON cards.pln_id=plans.pln_id";
    $sql .= " WHERE cards.crd_success=1";
    $sql .= " AND cards.crd_cdate BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @tm = FCC::Class::Date::Utils->new(
            time => $ref->{crd_cdate},
            tz   => $self->{conf}->{tz}
        )->get(1);

        my @cols = (
            $ref->{crd_id},
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $self->quote_string( $ref->{pln_title} ),
            $tm[0] . '-'
              . $tm[1] . '-'
              . $tm[2] . ' '
              . $tm[3] . ':'
              . $tm[4] . ':'
              . $tm[5],
            $ref->{crd_point},
            $ref->{crd_price}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

#---------------------------------------------------------------------
#■レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」の各レコード合算金額
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	集計値
#---------------------------------------------------------------------
sub count10 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my $dbh = $self->{db}->connect_db();

    my $sql = "SELECT SUM(lsn_prof_price) FROM lessons";
    $sql .= " WHERE lsn_status IN (1, 12, 13)";
    $sql .= " AND lsn_status_date BETWEEN ${sepoch} AND ${eepoch}";

    my ($sum) = $dbh->selectrow_array($sql);
    unless ($sum) {
        $sum = 0;
    }
    return $sum;
}

#---------------------------------------------------------------------
#■レッスン管理 lesson の「完了」「会員緊急キャンセル」「会員放置キャンセル」のレコードのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1. 集計開始日 (YYYY-MM-DD)
#	2. 集計終了日 (YYYY-MM-DD)
#[戻り値]
#	Shift_JIS にエンコード済みの CSV データ
#---------------------------------------------------------------------
sub csv10 {
    my ( $self, $sdate, $edate ) = @_;

    # 引数をチェック
    my ( $sepoch, $eepoch ) = $self->check_date_range( $sdate, $edate );

    my @header_colmns = (
        'レッスンID',   '講師ID',     '講師ニックネーム', '会員ID',
        '会員ニックネーム', '代理店ID',    '授業ID',     '授業名',
        'レッスン開始日時', 'レッスン終了日時', 'ステータス',    'レッスン費',
        '講師報酬'
    );
    my $header = join( ',', @header_colmns );
    $header = Unicode::Japanese->new( $header, "utf8" )->conv("sjis");
    my @lines = ($header);

    my $sql = "SELECT lessons.lsn_id, lessons.prof_id, profs.prof_handle,";
    $sql .= " lessons.member_id, members.member_handle, members.seller_id,";
    $sql .= " lessons.course_id, courses.course_name,";
    $sql .= " lessons.lsn_status, lessons.lsn_stime, lessons.lsn_etime,";
    $sql .= " lessons.lsn_prof_fee, lessons.lsn_prof_price";
    $sql .= " FROM lessons";
    $sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
    $sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
    $sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
    $sql .= " WHERE lessons.lsn_status IN (1, 12, 13)";
    $sql .= " AND lessons.lsn_status_date BETWEEN ${sepoch} AND ${eepoch}";

    my $dbh = $self->{db}->connect_db();
    my $sth = $dbh->prepare($sql);
    $sth->execute();

    while ( my $ref = $sth->fetchrow_hashref ) {
        my @cols = (
            $ref->{lsn_id},
            $ref->{prof_id},
            $self->quote_string( $ref->{prof_handle} ),
            $ref->{member_id},
            $self->quote_string( $ref->{member_handle} ),
            $ref->{seller_id},
            $ref->{course_id},
            $self->quote_string( $ref->{course_name} ),
            $ref->{lsn_stime},
            $ref->{lsn_etime},
            $ref->{lsn_status},
            $ref->{lsn_prof_fee},
            $ref->{lsn_prof_price}
        );
        my $line = join( ',', @cols );
        $line = Unicode::Japanese->new( $line, "utf8" )->conv("sjis");
        push( @lines, $line );
    }
    $sth->finish();

    my $csv = join( "\n", @lines );
    return $csv;
}

sub quote_string {
    my ( $self, $str ) = @_;
    if ($str) {
        $str =~ s/\"/\"\"/g;

    }
    else {
        $str = '';
    }
    $str = '"' . $str . '"';
    return $str;
}


1;
