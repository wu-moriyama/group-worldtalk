#!/usr/bin/perl
#############################################################
#フォローメール配信
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
	use HTML::Template;
	use FCC::Class::DB;
	use FCC::Class::Syscnf;
	use FCC::Class::Date::Utils;
	use FCC::Class::Mail::Sendmail;
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
	#フォローメール・レコードを取得
	my $fml_list = &get_fml_list($dbh);
	#月額課金の会員を取得
	my $sub_members = &get_sub_members($dbh);
	#配信処理
	my $success = 0;
	my $error = 0;
	for my $fml (@{$fml_list}) {
		#対象の会員を抽出
		my $member_list = &get_member_list($c, $dbh, $fml, $sub_members);
		unless($member_list) { next; }
		unless(@{$member_list}) { next; }
		#配信
		my $res = &deliver_mail($c, $dbh, $fml, $member_list);
		$success += $res->{success};
		$error += $res->{error};
	}
	#DB切断
	$db->disconnect_db();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. : success=${success}, error=${error}");
	exit;
}



#############################################################
# サブルーチン
#############################################################

sub get_fml_list {
	my($dbh) = @_;
	my $sth = $dbh->prepare("SELECT * FROM fmls");
	$sth->execute();
	my $list = [];
	while( my $ref  = $sth->fetchrow_hashref ) {
		unless($ref->{fml_content}) { return; }
		push(@{$list}, $ref);
	}
	$sth->finish();
	return $list
}

sub get_sub_members {
	my($dbh) = @_;
	my $sth = $dbh->prepare("SELECT member_id FROM autos WHERE auto_status=1");
	$sth->execute();
	my $h = {};
	while( my($member_id) = $sth->fetchrow_array ) {
		$h->{$member_id} = 1;
	}
	$sth->finish();
	return $h
}

sub get_member_list {
	my($c, $dbh, $fml, $sub_members) = @_;
	my $fml_days = $fml->{fml_days};
	my $epoch = time - ( $fml_days * 86400 );
	#
	my @tm = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$c->{tz})->get(1);
	my $siso = "$tm[0]-$tm[1]-$tm[2] 00:00:00";
	my $stime = FCC::Class::Date::Utils->new(iso=>$siso, tz=>$c->{tz})->epoch();
	my $eiso = "$tm[0]-$tm[1]-$tm[2] 23:59:59";
	my $etime = FCC::Class::Date::Utils->new(iso=>$eiso, tz=>$c->{tz})->epoch();
	#
	my @cols = (
		'members.member_id',
		'members.member_email',
		'members.member_lastname',
		'members.member_firstname',
		'members.member_handle'
	);
	my $tbl = "";
	my @wheres = ();
	my $left_join = "";
	if($fml->{fml_base} == 1) {
		#最終ログイン日を基準
		$tbl = "logins LEFT JOIN members ON logins.member_id=members.member_id";
		push(@wheres, "(logins.lin_date BETWEEN ${stime} AND ${etime})");
	} elsif($fml->{fml_base} == 2) {
		#登録日を基準
		$tbl = "members";
		push(@wheres, "(members.member_cdate BETWEEN ${stime} AND ${etime})");
	} else {
		return [];
	}
	#
	push(@wheres, "members.member_status=1");
	my $sql = "SELECT " . join(", ", @cols) . " FROM " . $tbl;
	$sql .= " WHERE " . join(" AND ", @wheres);
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my $list = [];
	my $member_id_hash = {};
	while( my $ref  = $sth->fetchrow_hashref ) {
		my $member_id = $ref->{member_id};
		if($member_id_hash->{$member_id}) { next; }
		if($fml->{fml_cond} == 1) {
			#全会員
			push(@{$list}, $ref);
			$member_id_hash->{$member_id} = 1;
		} elsif($fml->{fml_cond} == 2) {
			#月額契約会員
			if($sub_members->{$member_id}) {
				push(@{$list}, $ref);
				$member_id_hash->{$member_id} = 1;
			}
		} elsif($fml->{fml_cond} == 3) {
			#スポット契約会員
			unless($sub_members->{$member_id}) {
				push(@{$list}, $ref);
				$member_id_hash->{$member_id} = 1;
			}
		}
	}
	$sth->finish();
	return $list
}

sub deliver_mail {
	my($c, $dbh, $fml, $member_list) = @_;
	my $res = {
		success => 0,
		error => 0
	};
	#テンプレート生成
	my $fml_content = $fml->{fml_content};
	my $t = HTML::Template->new(
		scalarref => \$fml_content,
		die_on_bad_params => 0,
		vanguard_compatibility_mode => 1,
		loop_context_vars => 1
	);
	while( my($k, $v) = each %{$c} ) {
		$t->param($k => $v);
	}
	#会員別に配信
	for my $member (@{$member_list}) {
		#会員情報をセット
		while( my($k, $v) = each %{$member} ) {
			$t->param($k => $v);
		}
		#ヘッダーとボディー
		my $eml = $t->output();
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

#my($dummy) = $eml =~ /\n(To.+)\n/;
#my $fml_id = $fml->{fml_id};
#print "\[${fml_id}\] ${dummy}\n";

		$mail->mailsend();
	 	if( my $error = $mail->error() ) {
	 		$res->{error} ++;
			&loging("warning", "failed to send a mail. ${error} : fml_id=$fml->{fml_id}, member_id=$member->{member_id}, member_email=$member->{member_email}");
	 	} else {
			$res->{success} ++;
		}
	}
	return $res;
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


