#!/usr/bin/perl
#############################################################
#デイリー・レポート
#1日に一回だけ実行
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
	#前日
	my %dt = FCC::Class::Date::Utils->new(time=>time-86400, tz=>$c->{tz})->get_formated();
	my $yst = "$dt{Y}-$dt{m}-$dt{d}";
	#
	my $rep = {};
	#--------------------------------------------------------------
	#会員数 - 新規会員登録数
	$rep->{new_member_num} = &get_member_num($c, $dbh, $yst);
	#会員数 - 会員登録数合計
	$rep->{member_num} = &get_member_num($c, $dbh);
	#--------------------------------------------------------------
	#本日の購入ポイント数 - クレジット単発ポイント購入
	$rep->{point_41} = &get_paid_point($c, $dbh, $yst, 41);
	#本日の購入ポイント数 - クレジット月次自動ポイント購入
	$rep->{point_42} = &get_paid_point($c, $dbh, $yst, 42);
	#本日の購入ポイント数 - 銀行振込単発ポイント購入
	$rep->{point_43} = &get_paid_point($c, $dbh, $yst, 43);
	#本日の購入ポイント数 - 合計
	$rep->{point_sum} = $rep->{point_41} + $rep->{point_42} + $rep->{point_43};
	#--------------------------------------------------------------
	#月額コースの合計会員数
	$rep->{subscriber_num} = &get_subscriber_num($c, $dbh);
	#--------------------------------------------------------------
	#DB切断
#	$db->disconnect_db();
	#メール送信
	my $ot = new FCC::Class::Tmpl(conf=>$c, db=>$db, memd=>$memd);
	my $t = $ot->get_template_object("adm9001");
	while( my($k, $v) = each %dt ) {
		if($k =~ /^(M|D)$/) { next; }
		$rep->{"dt_${k}"} = $v;
	}
	&send_mail($c, $t, $rep);
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

sub get_member_num {
	my($c, $dbh, $yst) = @_;
	my $sql = "SELECT COUNT(member_id) FROM members WHERE ";
	if($yst) {
		my $s = FCC::Class::Date::Utils->new(iso=>"${yst} 00:00:00", tz=>$c->{tz})->epoch();
		my $e = FCC::Class::Date::Utils->new(iso=>"${yst} 23:59:59", tz=>$c->{tz})->epoch();
		$sql .= "(member_cdate BETWEEN ${s} AND ${e}) AND ";
	}
	$sql .= "(member_status=1 OR member_status=2)";
	my($num) = $dbh->selectrow_array($sql);
	return $num;
}

sub get_paid_point {
	my($c, $dbh, $yst, $mbract_reason) = @_;
	my $s = FCC::Class::Date::Utils->new(iso=>"${yst} 00:00:00", tz=>$c->{tz})->epoch();
	my $e = FCC::Class::Date::Utils->new(iso=>"${yst} 23:59:59", tz=>$c->{tz})->epoch();
	my $sql = "SELECT SUM(mbract_price) FROM mbracts WHERE (mbract_cdate BETWEEN ${s} AND ${e}) AND mbract_reason=${mbract_reason}";
	my($point) = $dbh->selectrow_array($sql);
	return $point ? $point : 0;
}

sub get_subscriber_num {
	my($c, $dbh) = @_;
	my $sql = "SELECT COUNT(auto_id) FROM autos WHERE auto_status=1";
	my($num) = $dbh->selectrow_array($sql);
	return $num;
}

sub send_mail {
	my($c, $t, $ref) = @_;
	#置換
	while( my($k, $v) = each %{$ref} ) {
		$t->param($k => $v);
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


