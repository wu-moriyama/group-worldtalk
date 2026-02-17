#!/usr/bin/perl
#############################################################
#月額課金をPayPal NVPでリクエスト
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
	use FCC::Class::String::Conv;
	use FCC::Class::Member;
	use FCC::Class::Auto;
	use FCC::Class::Card;
	use FCC::Class::Mbract;
	use FCC::Class::Mail::Sendmail;
	use FCC::Class::Tmpl;
	use Date::Pcalc;
	use HTTP::Request::Common;
	use LWP::UserAgent;
	use CGI::Utils;
}

#############################################################

my $BASE_DIR = '/var/www/WTE';
my $FCC_SELECTOR = 'paypal_nvp';

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


	$c->{BASE_DIR} = $BASE_DIR;
	$c->{FCC_SELECTOR} = $FCC_SELECTOR;


	#autosテーブルから月額課金候補のレコードを取得
	my $candidate_auto_list = &get_candidate_auto_list($c, $dbh);
	#課金処理
	my $oauto = new FCC::Class::Auto(conf=>$c, db=>$db);
	my $ocard = new FCC::Class::Card(conf=>$c, db=>$db);
	my $ombract = new FCC::Class::Mbract(conf=>$c, db=>$db);
	my $ot = new FCC::Class::Tmpl(conf=>$c, db=>$db, memd=>$memd);
	my $success_num = 0;
	my $error_num = 0;
	for my $auto (@{$candidate_auto_list}) {
		if( ! $auto->{member_id} ) {
			#会員情報がなければ（退会しているなら）、自動課金を取りやめにする
			eval { $oauto->stop_subscription({ member_id => $auto->{member_id}, auto_stop_reason => 3 }); };
			if($@) { &loging("error", "failed to run FCC::Class::Auto::stop_subscription() : $@"); }
			$error_num ++;
			next;
		} elsif( $auto->{member_status} != 1 ) {
			#会員ステータスが1でなければ、自動課金を取りやめにする
			eval { $oauto->stop_subscription({ member_id => $auto->{member_id}, auto_stop_reason => 5 }); };
			if($@) { &loging("error", "failed to run FCC::Class::Auto::stop_subscription() : $@"); }
			$error_num ++;
			next;
		} else {
			#PayPalに自動課金をリクエスト
			my $crd_success = paypal_nvp($c, $dbh, $auto, $ocard, $oauto, $ombract, $ot);
			if($crd_success == 1) {
				$success_num ++;
			} else {
				$error_num ++;
			}
		}
	}
	#DB切断
	$db->disconnect_db();
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. successs:${success_num}, error:${error_num}");
	exit;
}



#############################################################
# サブルーチン
#############################################################

sub paypal_nvp {
	my($c, $dbh, $auto, $ocard, $oauto, $ombract, $ot) = @_;
	#cardsテーブルにレコードを追加
	my $pln_point = $auto->{pln_point};
	my $card;
	eval {
		$card = $ocard->add({
			member_id => $auto->{member_id},
			pln_id    => $auto->{pln_id},
			auto_id   => $auto->{auto_id},
			crd_price => $auto->{pln_price},
#			crd_point => $auto->{auto_point},
			crd_point => $pln_point,
			crd_subscription => 1,
			crd_ref => 1
		});
	};
	if($@) {
		&loging("error", "failed to run FCC::Class::Card::add() : $@");
		return 0;
	}

	#リクエスト・パラメータ
	my $vars = {
		"VERSION"       => "84.0",
		"USER"          => $c->{paypal_nvp_username},
		"PWD"           => $c->{paypal_nvp_password},
		"SIGNATURE"     => $c->{paypal_nvp_signature},
		"METHOD"        => "DoReferenceTransaction",
		"PAYMENTACTION" => "Sale",
		"REFERENCEID"   => $auto->{auto_txn_id},
		"AMT"           => $auto->{pln_price},
		"CURRENCYCODE"  => "JPY",
		"DESC"          => $auto->{pln_id},
		"CUSTOM"        => join("-", $card->{crd_id}, $auto->{member_id}, $auto->{pln_id}),
		"INVNUM"        => $card->{crd_id}
	};
	#HTTPリクエスト
	my $ua = LWP::UserAgent->new();
	my $res = $ua->post($c->{paypal_nvp_url}, $vars);
	#HTTPレスポンスの評価
	my $crd_success = 0;
	my $crd_nvp_message = "";
	my $result = {};
	if ( $res->is_success ) {
		$result = CGI::Utils->new()->urlDecodeVars($res->content);
		while( my($k, $v) = each %{$result} ) {
			$crd_nvp_message .= "${k}: ${v}\n";
		}
		if($result->{ACK} =~ /^Success/) {
			$crd_success = 1;
		} else {
			$crd_success = 2;
		}
	} else {
		$crd_success = 2;
		$crd_nvp_message = $res->status_line;
	}
	#
	my $now = time;
	my @tm = FCC::Class::Date::Utils->new(time=>$now, tz=>$c->{tz})->get(1);
	#autosテーブル操作
	my $auto_updates = {
		auto_id    => $auto->{auto_id},
		crd_id     => $card->{crd_id},
		auto_mdate => $now,
	};
	if($crd_success == 1) {
		$auto_updates->{auto_last_ym} = $tm[0] . $tm[1];
		$auto_updates->{auto_count}   = $auto->{auto_count} + 1;
		$auto_updates->{auto_txn_id} = $result->{TRANSACTIONID};
	} else {
		$auto_updates->{auto_status}      = 0;
		$auto_updates->{auto_sdate}       = $now;
		$auto_updates->{auto_stop_reason} = 2;
	}
	$auto = $oauto->mod($auto_updates);
	#ポイントチャージ
	my $mbract;
	if($crd_success == 1) {
		$mbract = $ombract->charge({
			member_id => $auto->{member_id},
			seller_id => $auto->{seller_id},
			mbract_type => 1,
			mbract_reason => 42,
#			mbract_price => $auto->{auto_point},
			mbract_price => $pln_point,
			crd_id => $card->{crd_id},
			auto_id => $auto->{auto_id}
		});
	}
	#カード決済情報をアップデート
	my $new_card = $ocard->mod({
		crd_id => $card->{crd_id},
		mbract_id => $mbract ? $mbract->{mbract_id} : 0,
		auto_id => $auto->{auto_id},
		crd_rdate => $now,
		crd_success => $crd_success,
		crd_txn_id => $result->{TRANSACTIONID},
		crd_receipt_id => $result->{RECEIPTID},
		crd_nvp_message => Unicode::Japanese->new($crd_nvp_message, 'sjis')->get()
	});
	#通知メール送信
	my $mail_params = {};
	while( my($k, $v) = each %{$new_card} ) {
		$mail_params->{$k} = $v;
	}
	while( my($k, $v) = each %{$auto} ) {
		$mail_params->{$k} = $v;
	}
	&send_mail($c, $ot, $mail_params);
	#
	return $crd_success;
}

sub send_mail {
	my($c, $ot, $in) = @_;
	#通知先アドレスがセットされていなければ終了
	unless($in->{member_email}) { return; }
	#現在日時
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$c->{tz})->get(1);
	#
	my @tmpl_list;
	if($in->{crd_success} == 1) {
		push(@tmpl_list, 'ppl9011');
	} else {
		push(@tmpl_list, 'ppl9012');
	}
	for my $tmpl_id (@tmpl_list) {
		my $t = $ot->get_template_object($tmpl_id);
		#置換
		while( my($k, $v) = each %{$in} ) {
			$t->param($k => $v);
			if($k eq "crd_success") {
				$t->param("${k}_${v}" => 1);
			} elsif($k =~ /_(point|price)$/) {
				$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
			}
		}
		$t->param("ssl_host_url" => $c->{ssl_host_url});
		$t->param("sys_host_url" => $c->{sys_host_url});
		$t->param("pub_sender" => $c->{pub_sender});
		$t->param("pub_from" => $c->{pub_from});
		#現在日時
		for( my $i=0; $i<=9; $i++ ) {
			$t->param("tm_${i}" => $tm[$i]);
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
		$mail->mailsend();
	 	if( my $error = $mail->error() ) {
#	 		die $error;
	 	}
	}
}

sub get_candidate_auto_list {
	my($c, $dbh) = @_;
	#今日の日付
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$c->{tz})->get(0);
	my $d = $tm[2] + 0;
	#今月の月末日
	my $days_in_this_month = Date::Pcalc::Days_in_Month($tm[0], $tm[1]);
	#先月の年月
	my @last_ymd_array = Date::Pcalc::Add_Delta_YM($tm[0], $tm[1], $tm[2], 0, -1);
	my $last_ym = $last_ymd_array[0] . sprintf("%02d", $last_ymd_array[1]);
	$last_ym += 0;
	#
	my $sql = "SELECT autos.*, members.*, plans.* FROM autos";
	$sql .= " LEFT JOIN members ON autos.member_id=members.member_id";
	$sql .= " LEFT JOIN plans ON autos.pln_id=plans.pln_id";
	$sql .= "  WHERE auto_last_ym=${last_ym} AND auto_status=1";
	if($d < $days_in_this_month) {
		$sql .= " AND auto_day<=${d}";
	}
	my $sth = $dbh->prepare($sql);
	$sth->execute();
	my @list;
	while( my $h  = $sth->fetchrow_hashref ) {
		push(@list, $h);
	}
	$sth->finish();
	#
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


