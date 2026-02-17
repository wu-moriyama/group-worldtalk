#!/usr/bin/perl
#############################################################
#ポイント失効リマインダーメール送信
#1日に一回
#※絶対に一日に2回以上実行しないこと！
#　でないと、何通も会員にメールが届くことになります。
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
	use FCC::Class::String::Conv;
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
	my $num = 0;
	my $days = $c->{point_expire_notice_days};
	if($days > 0) {
		my $ot = new FCC::Class::Tmpl(conf=>$c, db=>$db, memd=>$memd);
		my $tmpl = $ot->get("pex9001");
		if($tmpl) {
			#有効期限の日付けを算出
			my $expire_epoch = time + (86400 * $days);
			my @expire = FCC::Class::Date::Utils->new(time=>$expire_epoch, tz=>$c->{tz})->get(1);
			my $expire_date = "$expire[0]-$expire[1]-$expire[2]";
			#対象の会員を取得
			my $sql = "SELECT * FROM members";
			$sql .= " WHERE member_point_expire='${expire_date}' AND member_point>0 AND member_status=1";
			my $sth = $dbh->prepare($sql);
			$sth->execute();
			my @member_list;
			while( my $member = $sth->fetchrow_hashref ) {
				my $t = HTML::Template->new(
					scalarref => \$tmpl,
					die_on_bad_params => 0,
					vanguard_compatibility_mode => 1,
					loop_context_vars => 1,
					case_sensitive => 1
				);
				#メール送信
				&send_mail($c, $t, $member);
				$num ++;
			}
			$sth->finish();
		}
	}
	#DB切断
	$db->disconnect_db();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. : ${num} mails were send.");
	exit;
}

#############################################################
# サブルーチン
#############################################################

sub send_mail {
	my($c, $t, $ref) = @_;
	#ポイント有効日時
	my $member_point_expire = $ref->{member_point_expire};
	my($eY, $eM, $eD) = $ref->{member_point_expire} =~ /^(\d{4})\-(\d{2})\-(\d{2})/;
	my $expire_epoch = FCC::Class::Date::Utils->new(iso=>"${eY}-${eM}-${eD} 23:59:59", tz=>$c->{tz})->epoch();
	my %expire_fmt = FCC::Class::Date::Utils->new(time=>$expire_epoch, tz=>$c->{tz})->get_formated();
	while( my($k, $v) = each %expire_fmt ) {
		$ref->{"member_point_expire_${k}"} = $v;
	}
	#置換
	while( my($k, $v) = each %{$ref} ) {
		$t->param($k => $v);
		if($k =~ /^member_(point|coupon)/) {
			$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
		}
	}
	while( my($k, $v) = each %{$c} ) {
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
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


