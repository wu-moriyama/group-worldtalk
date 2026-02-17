#!/usr/bin/perl
#############################################################
#仮登録有効期限切れ会員削除
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
}
#############################################################

&main();

sub main {
	&loging("notice", "started.");
	my $start = time;
	#本スクリプトが現在起動中かどうかをチェック
	&double_execute_check();
	#デフォルト設定をロード
	my($c, $dbh) = &load_conf();
	#保存と削除の境界epoch秒を算出
	my $epoch = time - 86400 * $c->{reg_interim_expire};
	#仮登録有効期限切れ会員データを削除
	my $sql = "DELETE FROM members WHERE member_cdate<${epoch} AND member_status=2";
	my $deleted = 0;
	eval {
		$deleted = $dbh->do($sql);
		$dbh->commit();
	};
	if($@) {
		$dbh->rollback();
		$dbh->disconnect();
		&error("failed to delete member records. : ${sql} : $@");
	}
	$deleted += 0;
	#DB切断
	$dbh->disconnect();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. ${deleted} records were deleted. ${trans_sec}s");
	exit;
}

#############################################################
# サブルーチン
#############################################################

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
	#DB接続
	my $dbh = &connect_db(
		db_host => $c->{db_host},
		db_name => $c->{db_name},
		db_user => $c->{db_user},
		db_pass => $c->{db_pass},
		db_port => $c->{db_port}
	);
	#DBのシステム設定を取得
	eval {
		my $sth = $dbh->prepare("SELECT * FROM sysconf");
		$sth->execute();
		while( my($k, $v) = $sth->fetchrow_array ) {
			$c->{$k} = $v;
		}
		$sth->finish();
	};
	if($@) {
		$dbh->disconnect();
		&error("failed to fetch sysconf table records. : $@");
	}
	#
	return $c, $dbh;
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
