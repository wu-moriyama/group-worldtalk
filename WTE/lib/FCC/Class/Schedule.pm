package FCC::Class::Schedule;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Clone;
use CGI::Utils;
use Date::Pcalc;
use FCC::Class::Log;
use FCC::Class::Date::Utils;
use Data::Dumper;
use CGI;

sub init {
	my($self, %args) = @_;
	unless( $args{conf} && $args{db} ) {
		croak "parameters are lacking.";
	}
	$self->{conf} = $args{conf};
	$self->{db} = $args{db};
	#
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	$self->{today} = "$tm[0]$tm[1]$tm[2]";
	$self->{nowhm} = "$tm[3]$tm[4]";
	#曜日の日本語表記
	$self->{week_map} = ["日", "月", "火", "水", "木", "金", "土", "日"];
	#schedulesテーブルの全カラム名のリスト
	#20201228
	$self->{table_cols} = {
		sch_id    => "識別ID",
		prof_id   => "講師識別ID",
		lsn_id    => "レッスン識別ID",
		course_id    => "コース識別ID",
		group_id    => "グループ識別ID",
		group_start_flag    => "グループ開始時間フラグ 1.開始時間のレコード",
		group_count    => "グループ枠数",
		sch_cdate => "登録日時",
		sch_stime => "開始時刻",
		sch_etime => "終了時刻"
	};
	#
	my @country_lines = split(/\n+/, $self->{conf}->{prof_countries});
	$self->{prof_country_hash} = {};
	$self->{prof_country_list} = [];
	for my $line (@country_lines) {
		if( $line =~ /^([a-z]{2})\s+(.+)/ ) {
			my $code = $1;
			my $name = $2;
			$self->{prof_country_hash}->{$code} = $name;
			push(@{$self->{prof_country_list}}, [$code, $name]);
		}
	}
	#
	my $unit = $self->{conf}->{lesson_reservation_limit_unit};
	my $limit = $self->{conf}->{lesson_reservation_limit};
	my $s;
	if( $unit eq "m") {
		my $epoch = time + (($limit + 1) * 60);
		my($sY, $sM, $sD, $sh, $sm) = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
		$s = $sY . $sM . $sD . $sh . $sm;
	} elsif( $unit eq "h" ) {
		my $epoch = time + (($limit + 1) * 3600);
		my($sY, $sM, $sD, $sh) = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
		$s = $sY . $sM . $sD . $sh . "00";
	} else {
		my $epoch = time + (($limit + 1) * 86400);
		my($sY, $sM, $sD) = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
		$s = $sY . $sM . $sD . "0000";
	}
	$self->{available_datetime_s} = $s;
	#
	my($eY, $eM) = Date::Pcalc::Add_Delta_YM($tm[0], $tm[1], $tm[2], 0, $self->{conf}->{schedule_months});
	my $eD = Date::Pcalc::Days_in_Month($eY, $eM);
	$self->{available_datetime_e} = $eY . sprintf("%02d", $eM) . sprintf("%02d", $eD) . "2359";
}

sub get_available_datetime_s {
	my($self) = @_;
	return $self->{available_datetime_s};
}

sub get_available_datetime_e {
	my($self) = @_;
	return $self->{available_datetime_e};
}

#---------------------------------------------------------------------
#■識別IDからスケジュール取得
#---------------------------------------------------------------------
#[引数]
#	1:識別ID
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get {
	my($self, $sch_id) = @_;
	if( ! $sch_id || $sch_id =~ /[^\d]/ ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_sch_id = $dbh->quote($sch_id);
	my $sql = "SELECT schedules.*, profs.* FROM schedules LEFT JOIN profs ON schedules.prof_id=profs.prof_id WHERE schedules.sch_id=${q_sch_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	if($ref) {
		$self->add_datetime_info($ref);
		$self->add_prof_info($ref);
	}
	#
	return $ref;
}


#---------------------------------------------------------------------
#■講師識別IDと開始日時からスケジュール取得
#---------------------------------------------------------------------
#[引数]
#	1:講師識別ID
#	2:開始日時（YYYYMMDDhhmm）
#[戻り値]
#	hashrefを返す
#---------------------------------------------------------------------
sub get_from_stime {
	my($self, $prof_id, $stime) = @_;
	if( ! $prof_id || $prof_id =~ /[^\d]/ ) {
		croak "a parameter is invalid: " . $prof_id;
	}
	if( $stime !~ /^\d{12}$/ ) {
		croak "a parameter is invalid: " . $stime;
	}
	#
	my($Y, $M, $D, $h, $m) = $stime =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})/;
	my $sch_stime = "${Y}-${M}-${D} ${h}:${m}:00";
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SELECT
	my $q_prof_id = $dbh->quote($prof_id);
	my $q_sch_stime = $dbh->quote($sch_stime);
	my $ref = $dbh->selectrow_hashref("SELECT * FROM schedules WHERE prof_id=${q_prof_id} AND sch_stime=${q_sch_stime}");
	if($ref) {
		$self->add_datetime_info($ref);
		$self->add_prof_info($ref);
	}
	#
	return $ref;
}

#---------------------------------------------------------------------
#■スケジュール登録
#---------------------------------------------------------------------
#[引数]
#	1: arrayref
#[戻り値]
#	登録数を返す
#---------------------------------------------------------------------
sub add {
	my($self, $list) = @_;
	if( ! $list || ref($list) ne "ARRAY" ) {
		croak "a parameter is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#
	my @sql_list;
	my $ct = 0;
	for my $ref (@{$list}) {
		my $rec = {};
		while( my($k, $v) = each %{$ref} ) {
			unless( exists $self->{table_cols}->{$k} ) { next; }
			if( defined $v ) {
				$rec->{$k} = $v;
			} else {
				$rec->{$k} = "";
			}
		}
		my $now = time;
		$rec->{sch_cdate} = $now;
		#SQL生成
		my @klist;
		my @vlist;
		while( my($k, $v) = each %{$rec} ) {
			push(@klist, $k);
			my $q_v;
			if($v eq "") {
				$q_v = "NULL";
			} else {
				$q_v = $dbh->quote($v);
			}

			#20201228
			#groupの頭のレコードをマーク
			if( $rec->{group_id} ){
				if($ct == 0){
					if($k eq 'group_start_flag'){
						$q_v = 1;
					}
				}
			}
			push(@vlist, $q_v);

		}
		my $sql = "INSERT IGNORE INTO schedules (" . join(",", @klist) . ") VALUES (" . join(",", @vlist) . ")";

		$ct++;

		push(@sql_list, $sql);
	}
	#INSERT
	my $num ++;
	my $sch_id;
	my $last_sql;
	eval {
		for my $sql (@sql_list) {
			$last_sql = $sql;
			$dbh->do($last_sql);
			$sch_id = $dbh->{mysql_insertid};
			$num ++;
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to insert records to schedules table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#
	return $num;
}

#---------------------------------------------------------------------
#■削除
#---------------------------------------------------------------------
#[引数]
#	1.識別ID（必須）
#[戻り値]
#	成功すれば削除データのhashrefを返す。
#	もし存在しないsch_idが指定されたら、未定義値を返す
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub del {
	my($self, $sch_id) = @_;
	#識別IDのチェック
	if( ! defined $sch_id || $sch_id =~ /[^\d]/) {
		croak "the value of sch_id in parameters is invalid.";
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#データ情報を取得
	my $sch = $self->get($sch_id);
	#
	if($sch->{lsn_id}) {
		croak "the schedule can't be deleted.";
	}
	#Delete
	my $deleted;
	my $last_sql;


	eval {

		my $sql = "SELECT group_id FROM schedules where sch_id='${sch_id}'";
		my $group_id = $dbh->selectrow_array($sql);

		if($group_id) {

			my $sql = "DELETE FROM schedules WHERE group_id='$group_id'";
			$deleted = $dbh->do($sql);

			my $sql = "DELETE FROM group_schedules WHERE group_id='$group_id'";
			$deleted = $dbh->do($sql);
		}

		my $sql = "DELETE FROM schedules WHERE sch_id=${sch_id}";
		$last_sql = $sql;
		$deleted = $dbh->do($sql);
		if($deleted > 0) {

		}
		$dbh->commit();

	};

	if($@) {
		$dbh->rollback();
		my $msg = "failed to delete a schedule record in schedules table.";
		FCC::Class::Log->new(conf=>$self->{conf})->loging("error", "${msg} : $@ : ${last_sql}");
		croak $msg;
	}
	#対象のレコードがなければundefを返す
	if($deleted == 0) {
		return undef;
	}
	#
	return $sch;
}

#---------------------------------------------------------------------
#■登録可能な日時かどうか
#---------------------------------------------------------------------
#[引数]
#	1: YYYYMMDDhhmm
#[戻り値]
#	登録可能な日時けなら1を、そうでなければ0を返す
#---------------------------------------------------------------------
sub is_available_datetime {
	my($self, $dt) = @_;
	if( ! $dt || $dt !~ /^\d{12}/ ) {
		return 0;
	}
	my $s = $self->{available_datetime_s};
	my $e = $self->{available_datetime_e};
	if($dt ge $s && $dt lt $e) {
		return 1;
	} else {
		return 0;
	}
}

#---------------------------------------------------------------------
#■登録可能な日付かどうか
#---------------------------------------------------------------------
#[引数]
#	1: YYYYMMDD
#[戻り値]
#	登録可能な日付けなら1を、そうでなければ0を返す
#---------------------------------------------------------------------
sub is_available_date {
	my($self, $ymd) = @_;
	if( ! $ymd || $ymd !~ /^\d{8}$/ ) {
		return 0;
	}
	if( $self->is_available_datetime("${ymd}0000") || $self->is_available_datetime("${ymd}2359") ) {
		return 1;
	} else {
		return 0;
	}
}

#---------------------------------------------------------------------
#■登録可能な年月かどうか
#---------------------------------------------------------------------
#[引数]
#	1: YYYYMM
#[戻り値]
#	登録可能な年月けなら1を、そうでなければ0を返す
#---------------------------------------------------------------------
sub is_available_month {
	my($self, $ym) = @_;
	if( ! $ym || $ym !~ /^\d{6}$/ ) {
		return 0;
	}
	my($y, $m) = $ym =~ /^(\d{4})(\d{2})/;
	my $d = Date::Pcalc::Days_in_Month($y, $m);
	if( $self->is_available_datetime("${ym}010000") || $self->is_available_datetime("${ym}${d}2359") ) {
		return 1;
	} else {
		return 0;
	}
}

#---------------------------------------------------------------------
#■トークタイムの時間のコマのリストを取得
#---------------------------------------------------------------------
#[引数]
#	1: トークタイムの単位時間（分）
#[戻り値]
#	トークタイムのリストをarrayrefで返す。
#	[ [0, 0, 0, 30], [0, 30, 1, 0], ...]
#	※ 00:00～00:30, 00:30～01:00, ...
#---------------------------------------------------------------------
sub get_time_line {
	my($self, $prof_step) = @_;
	if( ! $prof_step || $prof_step =~ /[^\d]/ ) {
		croak "prof_step is invalid.";
	}
	my @list;
	for( my $m=0; $m<1440; $m+=$prof_step ) {
		my $s = $m;
		my $sh = int($s / 60);
		my $sm = $s % 60;
		my $e = $m + $prof_step;
		my $eh = int($e / 60);
		my $em = $e % 60;
		push(@list, [$sh, $sm, $eh, $em]);
	}
	return \@list;
}

#---------------------------------------------------------------------
#■epoch秒から週の日付リストを取得
#---------------------------------------------------------------------
#[引数]
#	1: epoch秒（指定がなければ現在が適用される）
#[戻り値]
#	指定年月日を含む週の日付リストをarrayrefで返す。
#	日曜日で始まり土曜日で終わる
#---------------------------------------------------------------------
sub get_week_date_list_from_epoch {
	my($self, $epoch) = @_;
	unless($epoch) { $epoch = time; }
	#指定日の曜日
	my @date = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get();
	my $dow = $date[6];
	#指定日を含む週の日付リスト
	my @list;
	for( my $i = 0 - $dow; $i < 7 - $dow; $i ++ ) {
		my $e = $epoch + ( 86400 * $i );
		my %fmt = FCC::Class::Date::Utils->new(time=>$e, tz=>$self->{conf}->{tz})->get_formated();
		$fmt{wj} = $self->{week_map}->[$fmt{w}];
		$fmt{Dlc} = lc $fmt{D};
		$fmt{ymd} = $fmt{Y} . $fmt{m} . $fmt{d};
		if( ! $self->is_available_date($fmt{ymd}) ) {
			$fmt{disabled} = "disabled";
		} else {
			$fmt{disabled} = "";
		}
		push(@list, \%fmt);
	}
	#
	return \@list;
}

#---------------------------------------------------------------------
#■年月日から週の日付リストを取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#	3: 日
#[戻り値]
#	指定年月日を含む週の日付リストをarrayrefで返す。
#	[ [2011, 8, 7], [2011, 8, 8], ..., [2011, 8, 13] ]
#	日曜日で始まり土曜日で終わる
#---------------------------------------------------------------------
sub get_week_date_list {
	my($self, $y, $m, $d) = @_;
	my $epoch = $self->get_epoch_from_ymd($y, $m, $d);
	return $self->get_week_date_list_from_epoch($epoch);
}

#---------------------------------------------------------------------
#■年月日から先週の日付リストを取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#	3: 日
#	※いずれも指定がなければ現在が適用される
#[戻り値]
#	指定年月日を含む週の先週の日付リストをarrayrefで返す。
#	[ [2011, 8, 7], [2011, 8, 8], ..., [2011, 8, 13] ]
#	日曜日で始まり土曜日で終わる
#---------------------------------------------------------------------
sub get_last_week_date_list {
	my($self, $y, $m, $d) = @_;
	my $epoch = $self->get_epoch_from_ymd($y, $m, $d);
	$epoch -= ( 86400 * 7 );
	return $self->get_week_date_list_from_epoch($epoch);
}

#---------------------------------------------------------------------
#■年月日から来週の日付リストを取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#	3: 日
#	※いずれも指定がなければ現在が適用される
#[戻り値]
#	指定年月日を含む週の先週の日付リストをarrayrefで返す。
#	[ [2011, 8, 7], [2011, 8, 8], ..., [2011, 8, 13] ]
#	日曜日で始まり土曜日で終わる
#---------------------------------------------------------------------
sub get_next_week_date_list {
	my($self, $y, $m, $d) = @_;
	my $epoch = $self->get_epoch_from_ymd($y, $m, $d);
	$epoch += ( 86400 * 7 );
	return $self->get_week_date_list_from_epoch($epoch);
}

#---------------------------------------------------------------------
#■年月日からepoch秒を取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#	3: 日
#	※いずれも指定がなければ現在が適用される。
#[戻り値]
#	指定年月日の12:00:00のepoch秒を返す。
#---------------------------------------------------------------------
sub get_epoch_from_ymd {
	my($self, $y, $m, $d) = @_;
	if( $y && $m && $d && Date::Pcalc::check_date($y, $m, $d) ) {
		my $iso = $y . "-" . sprintf("%02d", $m) . "-" . sprintf("%02d", $d) . " 12:00:00";
		return FCC::Class::Date::Utils->new(iso=>$iso, tz=>$self->{conf}->{tz})->epoch();
	} else {
		croak "The specified date is invalid.";
	}
}

#---------------------------------------------------------------------
#■epoch秒から月の日付リストを取得
#---------------------------------------------------------------------
#[引数]
#	1: epoch秒（指定がなければ現在が適用される）
#[戻り値]
#	指定年月日を含む月の週リストをarrayrefで返す。
#	日曜日で始まり土曜日で終わるカレンダーに必要な日付がすべて入る
#	つまり先月と来月の日付も含まれる
#	[
#		[ {}, {}, {}, {}, {}, {}, {} ],
#		[ {}, {}, {}, {}, {}, {}, {} ],
#		[ {}, {}, {}, {}, {}, {}, {} ],
#		[ {}, {}, {}, {}, {}, {}, {} ],
#		[ {}, {}, {}, {}, {}, {}, {} ],
#		[ {}, {}, {}, {}, {}, {}, {} ]
#	]
#---------------------------------------------------------------------
sub get_month_date_list_from_epoch {
	my($self, $epoch) = @_;
	unless($epoch) { $epoch = time; }
	#指定の月の1日
	my @dt = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
	my $e = $self->get_epoch_from_ymd($dt[0], $dt[1], 1);
	my $ym = "$dt[0]$dt[1]";
	#指定月の1日を含む週の先週の初日
	my @ldt = FCC::Class::Date::Utils->new(time=>$e-(86400*7), tz=>$self->{conf}->{tz})->get();
	my $last_month_week_day_list = $self->get_week_date_list($ldt[0], $ldt[1], $ldt[2]);
	my $base = $last_month_week_day_list->[0];
	#指定月の日付リスト
	my @list;
	my $week_num = 0;
	while( $week_num <= 6 ) {
		#週の日付リストを取得
		my $week = $self->get_next_week_date_list($base->{Y}, $base->{n}, $base->{j});
		#当月のカレンダーにふさわしい日付かどうかをチェック
		if( $week->[0]->{ymd} !~ /^${ym}/ && $week->[6]->{ymd} !~ /^${ym}/ ) {
			last;
		}
		#
		for my $d (@{$week}) {
			$d->{othermonth} = ($d->{ymd} !~ /^${ym}/) ? "othermonth" : "";
			$d->{today} = ($d->{ymd} eq $self->{today}) ? "today" : "";
		}
		#
		push(@list, $week);
		$base = $week->[0];
		$week_num ++;
	}
	#
	return \@list;
}

#---------------------------------------------------------------------
#■年月から月の日付リストを取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#[戻り値]
#	get_month_date_list_from_epoch() と同様
#---------------------------------------------------------------------
sub get_month_date_list {
	my($self, $y, $m) = @_;
	my $epoch = $self->get_epoch_from_ymd($y, $m, 1);
	return $self->get_month_date_list_from_epoch($epoch);
}

#---------------------------------------------------------------------
#■年月から前月の最終日の情報を取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#[戻り値]
#	hashref
#---------------------------------------------------------------------
sub get_last_month_last_day_info {
	my($self, $y, $m) = @_;
	my $e = $self->get_epoch_from_ymd($y, $m, 1);
	$e -= 86400;
	my %fmt = FCC::Class::Date::Utils->new(time=>$e, tz=>$self->{conf}->{tz})->get_formated();
	$fmt{wj} = $self->{week_map}->[$fmt{w}];
	$fmt{Dlc} = lc $fmt{D};
	$fmt{ymd} = $fmt{Y} . $fmt{m} . $fmt{d};
	if( ! $self->is_available_date($fmt{ymd}) ) {
		$fmt{disabled} = "disabled";
	} else {
		$fmt{disabled} = "";
	}
	return \%fmt;
}

#---------------------------------------------------------------------
#■年月から来月の1日の情報を取得
#---------------------------------------------------------------------
#[引数]
#	1: 西暦
#	2: 月
#[戻り値]
#	hashref
#---------------------------------------------------------------------
sub get_next_month_first_day_info {
	my($self, $y, $m) = @_;
	my $d = Date::Pcalc::Days_in_Month($y, $m);
	my $e = $self->get_epoch_from_ymd($y, $m, $d);
	$e += 86400;
	my %fmt = FCC::Class::Date::Utils->new(time=>$e, tz=>$self->{conf}->{tz})->get_formated();
	$fmt{wj} = $self->{week_map}->[$fmt{w}];
	$fmt{Dlc} = lc $fmt{D};
	$fmt{ymd} = $fmt{Y} . $fmt{m} . $fmt{d};
	if( ! $self->is_available_date($fmt{ymd}) ) {
		$fmt{disabled} = "disabled";
	} else {
		$fmt{disabled} = "";
	}
	return \%fmt;
}

#---------------------------------------------------------------------
#■DBレコードを検索してリストで取得
#---------------------------------------------------------------------
#[引数]
#	1.検索パラメータを格納したhashref（必須ではない）
#		{
#			sch_id => スケジュール識別ID,
#			prof_id => 講師識別ID,
#           prof_id_list => 講師識別IDのリスト,
#			sch_sdate => スケジュール日（YYYYMMDD）
#			sch_date_s => 検索開始日（YYYYMMDD）
#			sch_date_e => 検索終了日（YYYYMMDD）
#			offset => オフセット値（デフォルト値：0）,
#			limit => リミット値（デフォルト値：20）,
#			sort => ソート条件のarrayref [ [ソートカラム名, 順序(ASC|DESC)], ... ]
#		}
#		上記パラメータに指定がなかった場合のでフォルト値
#		{
#			offset => 0,
#			limit => 20,
#			sort =>[ ['sch_stime', "ASC"] ]
#		}
#
#[戻り値]
#	検索結果を格納したhashref
#		{
#			list => 各レコードを格納したhashrefのarrayref,
#			hit => 検索ヒット数,
#			fetch => フェッチしたレコード数,
#			start => 取り出したレコードの開始番号（offset+1, ただしhit=0の場合はstartも0となる）,
#			end => 取り出したレコードの終了番号（offset+fetch, ただしhit=0の場合はendも0となる）,
#			params => 検索条件を格納したhashref
#		}
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub get_list {
	my($self, $in_params) = @_;
	if( defined $in_params && ref($in_params) ne "HASH" ) {
		croak "the 1st argument is invaiid.";
	}

	#20201227追加
	my $q = new CGI;
	my $course_id = $q->param('course_id');
	my $course_group_flag = $q->param('course_group_flag');

	#指定の検索条件を新たなhashrefに格納
	my $params = {};
	my @param_key_list = (
		'sch_id',
		'prof_id',
		'prof_id_list',
		'sch_sdate',
		'sch_date_s',
		'sch_date_e',
		'offset',
		'limit',
		'sort',
	);
	if( defined $in_params ) {
		for my $k (@param_key_list) {
			if(defined $in_params->{$k} && $in_params->{$k} ne "") {
				$params->{$k} = $in_params->{$k};
			}
		}
	}
	#検索条件にデフォルト値をセット
	my $defaults = {
		offset => 0,
		limit => 20,
		sort =>[ ['sch_stime', "ASC"] ]
	};
	while( my($k, $v) = each %{$defaults} ) {
		if( ! defined $params->{$k} && defined $v ) {
			$params->{$k} = $v;
		}
	}
	#検索条件のチェック
	while( my($k, $v) = each %{$params} ) {
		if($k eq "sch_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "prof_id") {
			if($v =~ /[^\d]/) {
				delete $params->{$k};
			}
		} elsif($k eq "prof_id_list") {
			if(ref($v) eq "ARRAY") {
				my $err = 0;
				for my $id (@{$v}) {
					if($id =~ /[^\d]/) {
						$err = 1;
						last;
					}
				}
				if($err) {
					delete $params->{$k};
				}
			} else {
				delete $params->{$k};
			}
		} elsif($k eq "sch_sdate") {
			if($v !~ /^\d{8}$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
		} elsif($k eq "sch_date_s") {
			if($v !~ /^\d{8}$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
		} elsif($k eq "sch_date_e") {
			if($v !~ /^\d{8}$/) {
				croak "the value of ${k} in parameters is invalid.";
			}
		} elsif($k eq "offset") {
			if($v =~ /[^\d]/) {
				croak "the value of offset in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "limit") {
			if($v =~ /[^\d]/) {
				croak "the value of limit in parameters is invalid.";
			}
			$params->{$k} = $v + 0;
		} elsif($k eq "sort") {
			if( ref($v) ne "ARRAY") {
				croak "the value of sort in parameters is invalid.";
			}
			for my $ary (@{$v}) {
				if( ref($ary) ne "ARRAY") { croak "the value of sort in parameters is invalid."; }
				my $key = $ary->[0];
				my $order = $ary->[1];
				if($key !~ /^(sch_id|prof_id|sch_stime)$/) { croak "the value of sort in parameters is invalid."; }
				if($order !~ /^(ASC|DESC)$/) { croak "the value of sort in parameters is invalid."; }
			}
		}
	}
	#DB接続
	my $dbh = $self->{db}->connect_db();
	#SQLのWHERE句
	my @wheres;
	if(defined $params->{sch_id}) {
		push(@wheres, "schedules.sch_id=$params->{sch_id}");
	}
	if(defined $params->{prof_id}) {
		push(@wheres, "schedules.prof_id=$params->{prof_id}");
	}
	if(defined $params->{prof_id_list}) {
		if(@{$params->{prof_id_list}} > 0) {
			push(@wheres, "schedules.prof_id IN (" . join(", ", @{$params->{prof_id_list}}) . ")");
		} else {
			my $res = {
				list => [],
				hit => 0,
				fetch => 0,
				start => 0,
				end => 0,
				params => $params
			};
			return $res;
		}
	}
	if(defined $params->{sch_sdate}) {
		my($Y, $M, $D) = $params->{sch_sdate} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $s = $dbh->quote("${Y}-${M}-${D} 00:00:00");
		my $e = $dbh->quote("${Y}-${M}-${D} 23:59:59");
		push(@wheres, "(schedules.sch_stime BETWEEN ${s} AND ${e})");
	}
	if(defined $params->{sch_date_s}) {
		my($Y, $M, $D) = $params->{sch_date_s} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $v = $dbh->quote("${Y}-${M}-${D} 00:00:00");
		push(@wheres, "schedules.sch_stime >= ${v}");
	}
	if(defined $params->{sch_date_e}) {
		my($Y, $M, $D) = $params->{sch_date_e} =~ /^(\d{4})(\d{2})(\d{2})/;
		my $v = $dbh->quote("${Y}-${M}-${D} 23:59:59");
		push(@wheres, "schedules.sch_stime <= ${v}");
	}
	#レコード数
	my $hit = 0;
	{
		my $sql = "SELECT COUNT(schedules.sch_id) FROM schedules";
		if(@wheres) {
			$sql .= " WHERE ";
			$sql .= join(" AND ", @wheres);
		}
		($hit) = $dbh->selectrow_array($sql);
	}
	$hit += 0;
	#SELECT
	my @list;
	{
		my $sql = "SELECT schedules.*, profs.*,courses.course_name FROM schedules LEFT JOIN profs ON schedules.prof_id=profs.prof_id LEFT JOIN `courses` ON schedules.`course_id` = `courses`.course_id";
		#my $sql = "SELECT schedules.*, profs.* FROM schedules LEFT JOIN profs ON schedules.prof_id=profs.prof_id";
		if(@wheres) {
			my $where = join(" AND ", @wheres);
			$sql .= " WHERE ${where}";
		}
		#20201227追加
		if($course_group_flag){
			if( $course_id ){
				$sql .= " AND schedules.course_id = '$course_id'";
			}
		}else{
			#$sql .= " AND schedules.group_id = 0";
		}

		if(defined $params->{sort} && @{$params->{sort}} > 0) {
			my @pairs;
			for my $ary (@{$params->{sort}}) {
				push(@pairs, "schedules.$ary->[0] $ary->[1]");
			}
			$sql .= " ORDER BY " . join(",", @pairs);
		}
		$sql .= " LIMIT $params->{offset}, $params->{limit}";
		#



		#print "Content-type: text/html\n\n$sql\n"; exit(1);
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		while( my $ref = $sth->fetchrow_hashref ) {
			$self->add_datetime_info($ref);
			$self->add_prof_info($ref);
			$ref->{course_menu_id} = $ref->{course_id};
			push(@list, $ref);
		}
		$sth->finish();
	}
	#
	my $res = {};
	$res->{list} = \@list;
	$res->{hit} = $hit;
	$res->{fetch} = scalar @list;
	$res->{start} = 0;
	if($res->{fetch} > 0) {
		$res->{start} = $params->{offset} + 1;
		$res->{end} = $params->{offset} + $res->{fetch};
	}
	$res->{params} = $params;
	#
	return $res;
}

sub add_prof_info {
	my($self, $ref) = @_;
	$ref->{prof_country_name} = $self->{prof_country_hash}->{$ref->{prof_country}};
	$ref->{prof_residence_name} = $self->{prof_country_hash}->{$ref->{prof_residence}};
	my $prof_id = $ref->{prof_id};
	for(my $s=1; $s<=3; $s++ ) {
		$ref->{"prof_logo_${s}_url"} = "$self->{conf}->{prof_logo_dir_url}/${prof_id}.${s}.$self->{conf}->{prof_logo_ext}";
		$ref->{"prof_logo_${s}_w"} = $self->{conf}->{"prof_logo_${s}_w"};
		$ref->{"prof_logo_${s}_h"} = $self->{conf}->{"prof_logo_${s}_h"};
	}
}

sub add_datetime_info {
	my($self, $ref) = @_;
	my($sY, $sM, $sD, $sh, $sm) = $ref->{sch_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
	my($eY, $eM, $eD, $eh, $em) = $ref->{sch_etime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
	$ref->{stime} = ($sh + 0) . ":" . $sm;
	$ref->{etime} = ($eh + 0) . ":" . $em;
	$ref->{sY} = $sY;
	$ref->{sM} = $sM;
	$ref->{sD} = $sD;
	$ref->{sh} = $sh;
	$ref->{sm} = $sm;
	$ref->{eY} = $eY;
	$ref->{eM} = $eM;
	$ref->{eD} = $eD;
	$ref->{eh} = $eh;
	$ref->{em} = $em;
	#
	my $dt = $sY. $sM . $sD . $sh .$sm;
	$ref->{disabled} = $self->is_available_datetime($dt) ? "" : "disabled";
	#
	my $stime_epoch = FCC::Class::Date::Utils->new(iso=>"${sY}-${sM}-${sD} ${sh}:${sm}:00", tz=>$self->{conf}->{tz})->epoch();
	my %stime_fmt = FCC::Class::Date::Utils->new(time=>$stime_epoch, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %stime_fmt ) {
		$ref->{"sch_stime_${k}"} = $v;
	}
	#
	my $etime_epoch = FCC::Class::Date::Utils->new(iso=>"${eY}-${eM}-${eD} ${eh}:${em}:00", tz=>$self->{conf}->{tz})->epoch();
	my %etime_fmt = FCC::Class::Date::Utils->new(time=>$etime_epoch, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %etime_fmt ) {
		$ref->{"sch_etime_${k}"} = $v;
	}
}

1;
