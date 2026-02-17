#!/usr/bin/perl
#############################################################
#会員保持ポイントの有効期限切れ処理
# cronで1日に1回実行
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
	#
	#ポイント失効対象の会員を抽出
	my $member_list = &get_point_target_list($c, $dbh);
	#ポイントを失効させる
	my $success_num = 0;
	my $error_num = 0;
	my $olsn = new FCC::Class::Lesson(conf=>$c, db=>$db);
	for my $member (@{$member_list}) {
		my $member_id = $member->{member_id};
		my $seller_id = $member->{seller_id};
		my $member_point = $member->{member_point};
		if($member_point == 0) { next; }
		#ポイントの売り掛け
		my $member_receivable_point = $olsn->get_receivable($member_id, 1);
		my $minus_point = $member_point - $member_receivable_point;
		if($minus_point <= 0) { next; }
		#
		my $last_sql;
		eval {
			$last_sql = "UPDATE members SET member_point=${member_receivable_point} WHERE member_id=${member_id}";
			$dbh->do($last_sql);
			#
			$last_sql = &make_insert_sql("mbracts", {
				member_id     => $member_id,
				seller_id     => $seller_id,
				mbract_type   => 2,
				mbract_reason => 91,
				mbract_cdate  => time,
				mbract_price  => $minus_point
			});
			$dbh->do($last_sql);
			#
			$dbh->commit();
		};
		if($@) {
			$dbh->rollback();
			&loging("error", "failed to execute a sql. : ${last_sql} : $@");
			$error_num ++;
		} else {
			$success_num ++;
		}
	}
	#DB切断
	$dbh->disconnect();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. ${success_num} success, ${error_num} error.");
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

sub get_point_target_list {
	my($c, $dbh) = @_;
	#今日の日付
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$c->{tz})->get(1);
	my $today = "$tm[0]-$tm[1]-$tm[2]";
	#対象の会員を抽出
	my $sql = "SELECT * FROM members WHERE member_point_expire<'${today}' AND member_point>0";
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

sub load_sysconf {
	my($dbh) = @_;
	my $c = {};
	return $c;
}

sub connect_db {
	my(%args) = @_;
	my $db_host = $args{db_host};
	my $db_name = $args{db_name};
	my $db_user = $args{db_user};
	my $db_pass = $args{db_pass};
	my $db_port = $args{db_port};
	my $dsn = "dbi:mysql:database=${db_name};host=${db_host}";
	if($db_port) {
		$dsn .= ";port=${db_port}";
	}
	my $dbh = DBI->connect(
		"${dsn}",
		"${db_user}", "${db_pass}",
		{RaiseError => 1, AutoCommit => 0}
	) or &error("failed to database : $DBI::errstr");
	if($@) {
		&error("failed to connect to database. : $@");
	}
	return $dbh;
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
