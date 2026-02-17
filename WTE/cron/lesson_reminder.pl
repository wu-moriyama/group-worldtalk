#!/usr/bin/perl
#############################################################
#レッスン開始通知・終了通知の配信
#5分おきに実行
#############################################################
use strict;
use warnings;
BEGIN {
	use DBI;
	use FindBin;
	use lib "$FindBin::Bin/../lib";
	chdir $FindBin::Bin;
	use Config::Tiny;
	use Cache::Memcached::Fast;
	use FCC::Class::DB;
	use FCC::Class::Syscnf;
	use FCC::Class::Date::Utils;
	use FCC::Class::Mail::Sendmail;
	use FCC::Class::Tmpl;
}

#############################################################

&main();

sub main {
	&loging("notice", "started.");
	my $start = time;
	#本スクリプトが現在起動中かどうかをチェック
	&double_execute_check();
	#デフォルト設定をロード
	my $c = &load_conf();
	#memcachedに接続
	my @memcached_servers;
	if( $c->{memcached_servers1} ) {
		push(@memcached_servers, $c->{memcached_servers1});
	}
	if( $c->{memcached_servers2} ) {
		push(@memcached_servers, $c->{memcached_servers2});
	}
	my $memd = new Cache::Memcached::Fast({
		servers => \@memcached_servers,
		ketama_points => 150
	});
	#DB初期化
	my $db = new FCC::Class::DB(conf => $c);
	my $dbh = $db->connect_db();
	#システム設定情報を取得
	my $osc = new FCC::Class::Syscnf(conf=>$c, db=>$db, memd=>$memd);
	my $sc = $osc->get_from_db();
	while( my($k, $v) = each %{$sc} ) {
		$c->{$k} = $v;
	}
	#
	my $ot = new FCC::Class::Tmpl(conf=>$c, db=>$db, memd=>$memd);
	#レッスン開始通知
	my $s_lsn_num = &notice_lesson_start($c, $dbh, $osc, $ot);
	#レッスン終了通知
	my $e_lsn_num = &notice_lesson_end($c, $dbh, $osc, $ot);
	#DB切断
	$db->disconnect_db();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. : s_lsn_num=${s_lsn_num}, e_lsn_num=${e_lsn_num}");
	exit;
}

#############################################################
# サブルーチン
#############################################################

sub notice_lesson_start {
	my($c, $dbh, $osc, $ot) = @_;
	unless( $c->{lsn_reminder_timing} ) { return 0; }
	#しきい値の日時
	my $this_epoch = time + ( $c->{lsn_reminder_timing} * 3600 );
	#前回のしきい値の日時
	my $last_epoch = $c->{lesson_start_reminder_last_epoch};
	#前回のしきい値がなければ、しきい値を保存して終了
	unless($last_epoch) {
		&set_sys_conf($osc, { lesson_start_reminder_last_epoch => $this_epoch });
		return 0;
	}
	#しきい値の前後関係がおかしければ、しきい値を保存せずに終了
	#管理メニューにて lsn_reminder_timing を変更した際に起こりえる
	if($this_epoch <= $last_epoch) {
		return 0;
	}
	#しきい値の日時を保存
	&set_sys_conf($osc, { lesson_start_reminder_last_epoch => $this_epoch });
	#レッスン開始日時の範囲
	my %sfmt = FCC::Class::Date::Utils->new(time=>$last_epoch, tz=>$c->{tz})->get_formated();
	my $stm = "$sfmt{Y}-$sfmt{m}-$sfmt{d} $sfmt{H}:$sfmt{i}:$sfmt{s}";
	my %efmt = FCC::Class::Date::Utils->new(time=>$this_epoch, tz=>$c->{tz})->get_formated();
	my $etm = "$efmt{Y}-$efmt{m}-$efmt{d} $efmt{H}:$efmt{i}:$efmt{s}";
	#対象のレッスン情報を取得
	my $sql = "SELECT lessons.*, members.*, profs.*, courses.* FROM lessons";
	$sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
	$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
	$sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
	$sql .= " WHERE lessons.lsn_stime > '${stm}' AND lessons.lsn_stime <= '${etm}' AND lessons.lsn_cancel=0 AND lsn_status=0";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @lesson_list;
	while( my $ref = $sth->fetchrow_hashref ) {
		push(@lesson_list, $ref);
	}
	$sth->finish();
	#該当のレッスンがなければ終了
	unless(@lesson_list) { return 0; }
	#配信処理
	my $num = 0;
	for my $lsn (@lesson_list) {
		for my $tmpl_id ("lsn9001", "lsn9002") {
			#テンプレートをロード
			my $t = $ot->get_template_object($tmpl_id);
			#メール送信
			&send_mail($c, $t, $lsn);
		}
		$num ++;
	}
	return $num;
}

sub notice_lesson_end {
	my($c, $dbh, $osc, $ot) = @_;
	#しきい値の日時
	my $this_epoch = time;
	#前回のしきい値の日時
	my $last_epoch = $c->{lesson_end_reminder_last_epoch};
	#しきい値を保存
	&set_sys_conf($osc, { lesson_end_reminder_last_epoch => $this_epoch });
	#前回のしきい値がなければ終了
	unless($last_epoch) { return 0; }
	#しきい値の前後関係がおかしければ終了
	#本来は起こりえないけど、念のため。
	if($this_epoch <= $last_epoch) { return 0; }
	#レッスン開始日時の範囲
	my %sfmt = FCC::Class::Date::Utils->new(time=>$last_epoch, tz=>$c->{tz})->get_formated();
	my $stm = "$sfmt{Y}-$sfmt{m}-$sfmt{d} $sfmt{H}:$sfmt{i}:$sfmt{s}";
	my %efmt = FCC::Class::Date::Utils->new(time=>$this_epoch, tz=>$c->{tz})->get_formated();
	my $etm = "$efmt{Y}-$efmt{m}-$efmt{d} $efmt{H}:$efmt{i}:$efmt{s}";
	#対象のレッスン情報を取得
	my $sql = "SELECT lessons.*, members.*, profs.*, courses.* FROM lessons";
	$sql .= " LEFT JOIN members ON lessons.member_id=members.member_id";
	$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
	$sql .= " LEFT JOIN courses ON lessons.course_id=courses.course_id";
	$sql .= " WHERE lessons.lsn_etime > '${stm}' AND lessons.lsn_etime <= '${etm}' AND lessons.lsn_cancel=0 AND lsn_status=0";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @lesson_list;
	while( my $ref = $sth->fetchrow_hashref ) {
		push(@lesson_list, $ref);
	}
	$sth->finish();
	#該当のレッスンがなければ終了
	unless(@lesson_list) { return 0; }
	#配信処理
	my $num = 0;
	for my $lsn (@lesson_list) {
		for my $tmpl_id ("lsn9011", "lsn9012") {
			#テンプレートをロード
			my $t = $ot->get_template_object($tmpl_id);
			#メール送信
			&send_mail($c, $t, $lsn);
		}
		$num ++;
	}
	return $num;
}

sub set_sys_conf {
	my($osc, $ref) = @_;
	my $sc = $osc->get_from_db();
	while( my($k, $v) = each %{$ref} ) {
		$sc->{$k} = $v;
	}
	$osc->set($sc);
}

sub send_mail {
	my($c, $t, $ref) = @_;
	my($sY, $sM, $sD, $sh, $sm) = $ref->{lsn_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
	my($eY, $eM, $eD, $eh, $em) = $ref->{lsn_etime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
	$ref->{stime} = ($sh + 0) . ":" . $sm;
	$ref->{etime} = ($eh + 0) . ":" . $em;
	#レッスン開始日時
	my $stime_epoch = FCC::Class::Date::Utils->new(iso=>"${sY}-${sM}-${sD} ${sh}:${sm}:00", tz=>$c->{tz})->epoch();
	#my %stime_fmt = FCC::Class::Date::Utils->new(time=>$stime_epoch, tz=>"+00:00")->get_formated();
	my %stime_fmt = FCC::Class::Date::Utils->new(time=>$stime_epoch, tz=>$c->{tz})->get_formated();
	while( my($k, $v) = each %stime_fmt ) {
		$ref->{"lsn_stime_${k}"} = $v;
	}
	#レッスン修了日時
	my $etime_epoch = FCC::Class::Date::Utils->new(iso=>"${eY}-${eM}-${eD} ${eh}:${em}:00", tz=>$c->{tz})->epoch();
	#my %etime_fmt = FCC::Class::Date::Utils->new(time=>$etime_epoch, tz=>"+00:00")->get_formated();
	my %etime_fmt = FCC::Class::Date::Utils->new(time=>$etime_epoch, tz=>$c->{tz})->get_formated();
	while( my($k, $v) = each %etime_fmt ) {
		$ref->{"lsn_etime_${k}"} = $v;
	}
	#置換
	while( my($k, $v) = each %{$ref} ) {
		$t->param($k => $v);
		if($k eq "lsn_pay_type") {
			$t->param("${k}_${v}" => 1);
		}
	}
	$t->param("ssl_host_url" => $c->{ssl_host_url});
	$t->param("sys_host_url" => $c->{sys_host_url});
	$t->param("pub_sender" => $c->{pub_sender});
	$t->param("pub_from" => $c->{pub_from});
	#ヘッダーとボディー
	my $eml = $t->output();
	unless($eml) { next; }
	my $mail = new FCC::Class::Mail::Sendmail(
		sendmail => $c->{sendmail_path},
		smtp_host => $c->{smtp_host},
		smtp_port => $c->{smtp_port},
		smtp_auth_user => $c->{smtp_auth_user},
		smtp_auth_pass => $c->{smtp_auth_pass},
		smtp_timeout => $c->{smtp_timeout},
		eml => $eml,
		tz => $c->{tz}
	);
	eval {
		$mail->mailsend();
	};
}

sub double_execute_check {
	my @script_pathes = split(/\//, $0);
	my $script_name = pop @script_pathes;
	my $ps_result_str = `/bin/ps ux`;
	my @lines = split(/\n/, $ps_result_str);
	my $script_num = 0;
	for my $line (@lines) {
		if($line =~ /\Q${script_name}\E$/) {
			$script_num ++;
			if($script_num > 1) {
				my $msg = "this script has already been running.";
				&loging("error", $msg);
				die "$msg\n";
			}
		}
	}
}

sub load_conf {
	my $c = {};
	#デフォルト設定値を取得
	my $ct = Config::Tiny->read("../default/default.ini.cgi") or &error("failed to read deafult configurations file '../default/default.ini.cgi'. : $!");
	while( my($k, $v) = each %{$ct->{default}} ) {
		$c->{$k} = $v;
	}
	#
	return $c;
}

sub get_jst {
	my($epoch, $zero_pad) = @_;
	unless($epoch) {
		$epoch = time;
	}
	my($s, $m, $h, $D, $M, $Y, $w) = gmtime($epoch + 32400);
	$Y += 1900;
	$M ++;
	if($zero_pad) {
		$M = sprintf("%02d", $M);
		$D = sprintf("%02d", $D);
		$h = sprintf("%02d", $h);
		$m = sprintf("%02d", $m);
		$s = sprintf("%02d", $s);
	}
	return $Y, $M, $D, $h, $m, $s, $w;
}

sub loging {
	my($lebel, $msg) = @_;
	$msg =~ s/\n//g;
	#ログ格納ディレクトリ
	my $d = "./logs";
	#スクリプト名
	my($script) = $0 =~ /([^\/]+)$/;
	#現在日時
	my @tm = &get_jst(time, 1);
	my $now = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
	#ログファイル
	my $f = "${d}/$tm[0]$tm[1]$tm[2].log";
	open my $fh, ">>", $f or die "faield to open a log file. '${f}' : $@\n";
	print $fh "${now} \[${lebel}\]\[${script}\] ${msg}\n";
	close($fh);
}

sub error {
	my($msg) = @_;
	&loging("error", $msg);
	die "${msg}\n";
}


