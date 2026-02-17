#!/usr/bin/perl
#############################################################
#キャッシュ・テンポラリー画像ファイル削除スクリプト
#############################################################
use strict;
use warnings;
BEGIN {
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
	my $c = &load_conf();
	#ブログ登録時のテンポラリアイコン画像の削除
	my @dirs = (
		"$c->{member_logo_dir}/tmp",
		"$c->{prof_logo_dir}/tmp",
		"$c->{dwn_logo_dir}/tmp"
	);
	my $deleted = 0;
	my $now = time;
	for my $dir (@dirs) {
		if( ! -d $dir ) {
			&loging("warning", "${dir} is not found.");
			next;
		}
		opendir(DIR, $dir);
		my @files = readdir(DIR);
		closedir(DIR);
		for my $f (@files) {
			if($f !~ /^[a-zA-Z0-9]{32}\.[a-zA-Z]+$/) { next; }
			my $fpath = "${dir}/${f}";
			if( (stat($fpath))[9] < $now - 86400 ) {
				unlink $fpath;
				$deleted ++;
			}
		}
	}
	#ロギング
	my $trans_sec = time - $start;
	&loging("notice", "completed. ${deleted} files were deleted. ${trans_sec}s");
	exit;
}

#############################################################
# サブルーチン
#############################################################

sub load_conf {
	my $c = {};
	my $ct = Config::Tiny->read("../default/default.ini.cgi") or &error("failed to read deafult configurations file '../default/default.ini.cgi'. : $!");
	while( my($k, $v) = each %{$ct->{default}} ) {
		$c->{$k} = $v;
	}
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
