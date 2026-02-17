#!/usr/bin/perl
#############################################################
#レッスンのステータスを確定し、会員からポイントを引き落とす
#daily or hourly
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
	use FCC::Class::Lesson;
	use FCC::Class::Cpnact;
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
	my $sc = FCC::Class::Syscnf->new(conf=>$c, db=>$db, memd=>$memd)->get();
	while( my($k, $v) = each %{$sc} ) {
		$c->{$k} = $v;
	}
	#ステータスが未確定で確定期限が切れたレッスンを取得
	my $status_undetermined_lesson_list = &get_status_undetermined_lesson_list($c, $dbh);
	#レッスン・ステータスをアップデート
	my $olsn = new FCC::Class::Lesson(conf=>$c, db=>$db);
	for my $lsn (@{$status_undetermined_lesson_list}) {
		my $lsn_id = $lsn->{lsn_id};
		my $lsn_status = &determine_lsn_status($lsn);
		eval {
			$olsn->update_status($lsn_id, $lsn_status, $lsn);
		};
		if($@) {
			&loging("error", "failed to update lns_status. lsn_id=${lsn_id}. $@");
		}
	}
	#ステータスが確定し、まだ会員からポイントが引き落とされていないレッスンを取得
	my $charge_target_lesson_list = &get_charge_target_lesson_list($c, $dbh);
	#会員からポイントを引き落とす
	my $ocpn = new FCC::Class::Cpnact(conf=>$c, db=>$db);
	for my $lsn (@{$charge_target_lesson_list}) {
		my $act_sql;
		my $decr_sql;
		my $lsn_id = $lsn->{lsn_id};
		my $member_id = $lsn->{member_id};
		my $price = $lsn->{lsn_base_price};
		my $lsn_pay_type = $lsn->{lsn_pay_type};
		my $now = time;
		if($lsn_pay_type == 1) {
			#ポイント払い
			my $rec = {
				member_id     => $member_id,
				seller_id     => $lsn->{seller_id},
				mbract_type   => 2,
				mbract_reason => 51,
				mbract_cdate  => $now,
				mbract_price  => $price,
				lsn_id        => $lsn_id
			};
			$act_sql = &make_insert_sql("mbracts", $rec);
			$decr_sql = "UPDATE members SET member_point=member_point-${price} WHERE member_id=${member_id}";
		} elsif($lsn_pay_type == 2) {
			#クーポン払い
			my $rec = {
				coupon_id     => $lsn->{coupon_id},
				member_id     => $member_id,
				seller_id     => $lsn->{seller_id},
				cpnact_type   => 2,
				cpnact_reason => 51,
				cpnact_cdate  => $now,
				cpnact_price  => $price,
				lsn_id        => $lsn_id
			};
			$act_sql = &make_insert_sql("cpnacts", $rec);
			$decr_sql = "UPDATE members SET member_coupon=member_coupon-${price} WHERE member_id=${member_id}";
		} else {
			next;
		}
		my $charged_date_sql = "UPDATE lessons SET lsn_charged_date=${now} WHERE lsn_id=${lsn_id}";
		#
		my $last_sql;
		eval {
			if($price > 0) {
				$last_sql = $act_sql;
				$dbh->do($last_sql);
				#
				$last_sql = $decr_sql;
				$dbh->do($last_sql);
			}
			#
			$last_sql = $charged_date_sql;
			$dbh->do($last_sql);
			#
			$dbh->commit();
		};
		if($@) {
			$dbh->rollback();
			my $msg = "failed to execute a SQL statement. ${last_sql}";
			&loging("error", $msg);
		}
	}
	#DB切断
	$db->disconnect_db();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed.");
	exit;
}



#############################################################
# サブルーチン
#############################################################

sub make_insert_sql {
	my($tbl, $rec) = @_;
	my @klist;
	my @vlist;
	while( my($k, $v) = each %{$rec} ) {
		push(@klist, $k);
		push(@vlist, $v);
	}
	my $sql = "INSERT INTO ${tbl} (" . join(", ", @klist) . ") VALUES (" . join(", ", @vlist) . ")";
	return $sql;
}

sub determine_lsn_status {
	my($lsn) = @_;
	# "講師の報告（lsn_prof_repo） 会員の報告（lsn_member_repo）" => 課金ステータス確定期限切れ時の課金ステータス（lsn_status）
	my $mapping = {
		"0 0" =>  1,
		"0 1" =>  1,
		"0 2" => 23,
		"0 3" => 13,
		"0 9" => 23,
		"1 0" =>  1,
		"1 1" =>  1,
		"1 2" => 29,
		"1 3" =>  1,
		"1 9" => 29,
		"2 0" => 13,
		"2 1" =>  1,
		"2 2" => 29,
		"2 3" => 13,
		"2 9" => 29,
		"3 0" => 23,
		"3 1" =>  1,
		"3 2" => 23,
		"3 3" => 29,
		"3 9" => 29,
		"9 0" => 29,
		"9 1" =>  1,
		"9 2" => 29,
		"9 3" => 13,
		"9 9" => 29
	};
	my $key_name = $lsn->{lsn_prof_repo} . " " . $lsn->{lsn_member_repo};
	my $lsn_status = $mapping->{$key_name} ? $mapping->{$key_name} : 29;
	if($lsn->{lsn_cancel} > 0) {
		$lsn_status = 29;
	}
	return $lsn_status;
}

sub get_status_undetermined_lesson_list {
	my($c, $dbh) = @_;
	#リミット日時
	my $etime_limit_epoch = time - ($c->{lesson_bill_limit} * 60);
	my @etm = FCC::Class::Date::Utils->new(time=>$etime_limit_epoch, tz=>$c->{tz})->get(1);
	my $etime_limit = "$etm[0]-$etm[1]-$etm[2] $etm[3]:$etm[4]:00";

	#my $sql = "SELECT * FROM lessons WHERE lsn_etime<'${etime_limit}' AND lsn_status=0";
	my $sql = "SELECT lessons.*, profs.* FROM lessons";
	$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
	$sql .= " WHERE lessons.lsn_etime<'${etime_limit}' AND lessons.lsn_status=0";

	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @list;
	while( my $h  = $sth->fetchrow_hashref ) {
		push(@list, $h);
	}
	$sth->finish();
	return \@list;
}

sub get_charge_target_lesson_list {
	my($c, $dbh) = @_;
	#リミット日時
	my $etime_limit_epoch = time - ($c->{lesson_bill_limit} * 60);
	my @etm = FCC::Class::Date::Utils->new(time=>$etime_limit_epoch, tz=>$c->{tz})->get(1);
	my $etime_limit = "$etm[0]-$etm[1]-$etm[2] $etm[3]:$etm[4]:00";

	#my $sql = "SELECT * FROM lessons WHERE lsn_etime<'${etime_limit}' AND lsn_status>0 AND lsn_charged_date=0";
	my $sql = "SELECT lessons.*, profs.* FROM lessons";
	$sql .= " LEFT JOIN profs ON lessons.prof_id=profs.prof_id";
	$sql .= " WHERE lessons.lsn_etime<'${etime_limit}' AND lessons.lsn_status>0 AND lessons.lsn_charged_date=0";

	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @list;
	while( my $h  = $sth->fetchrow_hashref ) {
		push(@list, $h);
	}
	$sth->finish();
	return \@list;
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


