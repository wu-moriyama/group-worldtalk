#!/usr/bin/perl
#############################################################
#残ポイント・残クーポン集計して CSV 生成
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

	#ディレクトリの作成
	my $dir = '../data/pointcount';
	unless( -d $dir ) {
		if( ! mkdir $dir, 0777 ) {
			my $msg = "failed to make a directory.";
			die "Failed to make a directory ${dir}: $!";
		}
	}

	# 今日の日付
	my @tm = FCC::Class::Date::Utils->new(time=>$start, tz=>$c->{tz})->get(1);
	my $today = $tm[0] . $tm[1] . $tm[2] . $tm[3] . $tm[4]; # YYYYMMDDhhmm

	# CSV ファイルオープン
	my $fpath = "${dir}/${today}.csv";
	my $fh;
	unless(open $fh, ">", $fpath) {
		unlink $fpath;
		&error("Failed to create a csv file: ${fpath} : $!");
	}

	# CSV ヘッダー生成
	my @header_colmns = (
		'会員識別ID',
		'ハンドル名',
		'保持ポイント',
		'保持クーポン',
		'レッスンの売掛ポイント',
		'レッスンの売掛クーポン'
	);
	print $fh join(',', @header_colmns) . "\n";

	# 全会員の識別 ID のリストを取得
	my $member_id_list = &get_member_id_list($c, $dbh);

	# 集計開始
	my $olsn = new FCC::Class::Lesson(conf=>$c, db=>$db);
	for my $member_id (@{$member_id_list}) {
		# 会員のハンドル名、保持ポイント、保持クーポンを取得
		my $minfo = &get_member_info($c, $dbh, $member_id);

		# 売掛ポイントを取得
		my $receivable_point = $olsn->get_receivable($member_id, 1);

		# 売掛クーポンを取得
		my $receivable_coupon = $olsn->get_receivable($member_id, 2);

		# CSV に書き出し
		my @columns = (
			$minfo->{member_id},
			$minfo->{member_handle},
			$minfo->{member_point},
			$minfo->{member_coupon},
			$receivable_point,
			$receivable_coupon
		);
		print $fh join(',', @columns) . "\n";
	}
	close($fh);

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

sub get_member_id_list {
	my($c, $dbh) = @_;
	my $sql = "SELECT member_id FROM members ORDER BY member_id ASC";
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @list;
	while( my ($id) = $sth->fetchrow_array ) {
		push(@list, $id);
	}
	$sth->finish();
	return \@list;
}

sub get_member_info {
	my($c, $dbh, $member_id) = @_;
	my $sql = "SELECT member_id, member_handle, member_point, member_coupon FROM members";
	$sql .= " WHERE member_id=${member_id}";
	my $ref = $dbh->selectrow_hashref($sql);
	return $ref;
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


