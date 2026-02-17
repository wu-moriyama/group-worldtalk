#!/usr/bin/perl
#############################################################
#講師のスコアをアップデート
#daily
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
	use FCC::Class::Prof;
	use FCC::Class::Lesson;
	use FCC::Class::Date::Utils;
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
	#リミット日付
	my $limit_days = 30;
	my @stm = FCC::Class::Date::Utils->new(time=>time - (86400 * $limit_days), tz=>$c->{tz})->get(1);
	my $s_date = "$stm[0]-$stm[1]-$stm[2]";
	my @etm = FCC::Class::Date::Utils->new(time=>time - (86400 * 1), tz=>$c->{tz})->get(1);
	my $e_date = "$etm[0]-$etm[1]-$etm[2]";
	#講師スコアのハッシュを用意
	my $profs = &get_profs($dbh);
	#スコアのもととなるデータを算出
	&calc_rating($dbh, $profs, $s_date, $e_date);
	#スコアを算出しDBにセット
	&set_score($dbh, $profs);
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

sub set_score {
	my($dbh, $profs) = @_;
	my $last_sql;
	eval {
		while( my($prof_id, $r) = each %{$profs} ) {
			my $score = ($r->{r} * 1000) + $r->{n};
			$last_sql = "UPDATE profs SET prof_score=${score} WHERE prof_id=${prof_id}";
			$dbh->do($last_sql);
		}
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		my $msg = "failed to execute a SQL statement. ${last_sql}";
		&loging("error", $msg);
		die $msg;
	}
}

sub calc_rating {
	my($dbh, $profs, $s_date, $e_date) = @_;
	my $sql = "SELECT prof_id, lsn_member_repo_rating, lsn_status FROM lessons";
	$sql .= " WHERE (lsn_stime BETWEEN '${s_date} 00:00:00' AND '${e_date} 23:59:59')";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my $ratings = {};
	while( my($id, $rating, $status) = $sth->fetchrow_array ) {
		unless($profs->{$id}->{s}) { next; }
		unless($ratings->{$id}) {
			$ratings->{$id} = [0, 0, 0];
		}
		if( $rating && $rating > 0) {
			$ratings->{$id}->[0] += $rating;
			$ratings->{$id}->[1] ++;
		}
		if($status == 19) {
			$ratings->{$id}->[2] ++;
		}
	}
	$sth->finish();
	while( my($id, $r) = each %{$ratings} ) {
		my $avg = 0;
		if($r->[1] > 0) {
			$avg = int( $r->[0] / $r->[1] );
		}
		$profs->{$id}->{r} = $avg;
		$profs->{$id}->{n} = $r->[2];
	}
}

sub get_profs {
	my($dbh) = @_;
	my $sth = $dbh->prepare("SELECT prof_id, prof_status FROM profs");
	$sth->execute();
	my $h = {};
	while( my($id, $status)  = $sth->fetchrow_array ) {
		$h->{$id} = {
			n => 0, # 過去30日のレッスンの正常終了数
			r => 0, # 過去30日のレッスン評価の平均の整数値
			s => $status
		};
	}
	$sth->finish();
	return $h
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


