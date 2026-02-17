#---------------------------------------------------------------------#
#■日時関連処理モジュール
#
#・使い方
#
#	my $d = new FCC::Class::Date::Utils(
#		time => epoc秒,
#		tz   => タイムゾーン地域名(ex. Asia/Tokyo or +0900),
#		iso  => ISOフォーマットの日時(ex. 2008-09-23 03:54:02)
# 	);
#	※tzはオプション。指定がなければlocaltimeを使う(OS依存)。
#
#	■getメソッド
#
#	※日時情報を配列で取得
# 	$d->get();
#	※日時情報を配列で取得（日・時・分・秒を2桁固定でゼロで埋め合わせ）
#	$d->get(1);
#
#	返される配列
#	0:西暦(4桁)
#	1:月(1-12 or 01-12)
#	2:日(1-31 or 01-31)
#	3:時(0-23 or 00-23)
#	4:分(0-59 or 00-59)
#	5:秒(0-59 or 00-59)
#	6:曜日(0-6, 0->Sun, 1->Mon, .., 6->Sut)
#	7:夏時間フラグ(0 or 1)
#	8:タイムゾーンオフセット(ex. +0900)
#	9:タイムゾーン地域名(ex. Asia/Tokyo)
#
#	■epochメソッド
#	isoで指定した日時にタイムゾーンを考慮してepoch秒を返す
#
#	$d->epoch();
#
#	もしisoが指定されていなければ現在のepochを返す
#	また、isoに時分秒が指定されていなければ 00:00:00と見なして処理される。
#---------------------------------------------------------------------#

package FCC::Class::Date::Utils;
$VERSION = 1.00;
use strict;
use warnings;
use Carp;
use Date::Handler;
use Date::Pcalc qw(Delta_DHMS Days_in_Month);

sub new {
	my($caller, %args) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	$self->{time} = $args{time};
	$self->{iso} = $args{iso};
	$self->{tz} = $args{tz};
	bless $self, $class;
	return $self;
}

sub epoch {
	my($self) = @_;
	my $iso = $self->{iso};
	if( ! defined $iso || $iso eq "" ) {
		return time;
	}
	my($Y, $M, $D, $h, $m, $s);
	if($iso =~ /^(\d{4})\-(\d{1,2})\-(\d{1,2})\s+(\d{1,2})\:(\d{1,2})\:(\d{1,2})/) {
		$Y = $1;
		$M = $2;
		$D = $3;
		$h = $4;
		$m = $5;
		$s = $6;
	} elsif($iso =~ /^(\d{4})\-(\d{1,2})\-(\d{1,2})/) {
		$Y = $1;
		$M = $2;
		$D = $3;
		$h = 0;
		$m = 0;
		$s = 0;
	} else {
		croak "the value of iso must be \'YYYY-MM-DD hh:mm:ss\' format.";
	}
	my $offset = $self->get_tz_offset_sec();
	my $tz = $self->{tz};
	if( ! defined $tz || $tz eq "") {
		$tz = "GMT";
	}
	my $date = new Date::Handler({ date => [$Y,$M,$D,$h,$m,$s], time_zone => $tz, locale => 'C' });
	return $date->Epoch();
}

sub get_formated {
	my($self) = @_;
	#
	my @week_map = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");
	my @week_map_j = ("日", "月", "火", "水", "木", "金", "土", "日");
	my @week_full_map = ("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday");
	my @month_map = ("", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
	my @month_full_map = ("", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December");
	#
	my @tm = $self->get(1);
	# http://jp2.php.net/date
	my %fmt;
	# d 日。二桁の数字（先頭にゼロがつく場合も） 01 から 31
	$fmt{d} = $tm[2];
	# D 曜日。3文字のテキスト形式。 Mon から Sun
	$fmt{D} = $week_map[$tm[6]+0];
	# j 日。先頭にゼロをつけない。 1 から 31
	$fmt{j} = $tm[2] + 0;
	# l (小文字の 'L') 曜日。フルスペル形式。 Sunday から Saturday
	$fmt{l} = $week_full_map[$tm[6]+0];
	# N ISO-8601 形式の、曜日の数値表現 (PHP 5.1.0 で追加)。 1（月曜日）から 7（日曜日）
	if($tm[6] == 0) {
		$fmt{N} = 7;
	} else {
		$fmt{N} = $tm[6];
	}
	# S 英語形式の序数を表すサフィックス。2 文字。 st, nd, rd または th。 jと一緒に使用する ことができる。

	# w 曜日。数値。 0 (日曜)から 6 (土曜)
	$fmt{w} = $tm[6];
	# wj 曜日（漢字）（日、月、火...）
	$fmt{wj} = $week_map_j[$tm[6]+0];
	# z 年間の通算日。数字。(ゼロから開始) 0 から 365

	# W ISO-8601 月曜日に始まる年単位の週番号 (PHP 4.1.0 で追加) 例: 42 (年の第 42 週目)

	# F 月。フルスペルの文字。 January から December
	$fmt{F} = $month_full_map[$tm[1]+0];
	# m 月。数字。先頭にゼロをつける。 01 から 12
	$fmt{m} = $tm[1];
	# M 月。3 文字形式。 Jan から Dec
	$fmt{M} = $month_map[$tm[1]+0];
	# n 月。数字。先頭にゼロをつけない。 1 から 12
	$fmt{n} = $tm[1] + 0;
	# t 指定した月の日数。 28 から 31
	$fmt{t} = Date::Pcalc::Days_in_Month($tm[0],$tm[1]);
	# L 閏年であるかどうか。 1なら閏年。0なら閏年ではない。

	# o ISO-8601 形式の年。これは Y ほぼ同じだが、ISO 週番号 （W）が前年あるいは翌年に属する場合がある点で 異なる（PHP 5.1.0 で追加）。 例: 1999 あるいは 2003

	# Y 年。4 桁の数字。 例: 1999または2003
	$fmt{Y} = $tm[0];
	# y 年。2 桁の数字。 例: 99 または 03
	$fmt{y} = substr($tm[0], 2, 2);
	# a 午前または午後（小文字） am または pm
	# A 午前または午後（大文字） AM または PM
	if($tm[3] < 12) {
		$fmt{a} = "am";
		$fmt{A} = "AM";
	} else {
		$fmt{a} = "pm";
		$fmt{A} = "PM";
	}
	# B Swatch インターネット時間 000 から 999

	# g 時。12時間単位。先頭にゼロを付けない。 1 から 12
	$fmt{g} = $tm[3] + 0 % 12;
	# G 時。24時間単位。先頭にゼロを付けない。 0 から 23
	$fmt{G} = $tm[3] + 0;
	# h 時。数字。12 時間単位。 01 から 12
	$fmt{h} = sprintf("%02d", $fmt{g});
	# H 時。数字。24 時間単位。 00 から 23
	$fmt{H} = $tm[3];
	# i 分。先頭にゼロをつける。 00 から 59
	$fmt{i} = $tm[4];
	# s 秒。先頭にゼロをつける。 00 から 59
	$fmt{s} = $tm[5];
	# u マイクロ秒 (PHP 5.2.2 で追加)。 例: 54321 

	# e タイムゾーン識別子（PHP 5.1.0 で追加） 例: UTC, GMT, Atlantic/Azores 
	$fmt{e} = $tm[9];
	# I (大文字の i) サマータイム中か否か 1ならサマータイム中。 0ならそうではない。
	$fmt{I} = $tm[7];
	# O グリニッジ標準時 (GMT) との時差 例: +0200
	$fmt{O} = $tm[8];
	# P グリニッジ標準時 (GMT) との時差。時間と分をコロンで区切った形式 (PHP 5.1.3 で追加)。 例: +02:00
	$fmt{P} = $tm[8];
	$fmt{P} =~ s/(\d{2})$/\:$1/;
	# T タイムゾーンの略称 例: EST, MDT ...

	# Z タイムゾーンのオフセット秒数。 UTC の西側のタイムゾーン用のオフセットは常に負です。そして、 UTC の東側のオフセットは常に正です。 -43200 から 50400
	{
		my($h, $m) = $tm[8] =~ /(\d{2})(\d{2})$/;
		my $z = $h * 3600 + $m * 60;
		if($tm[8] =~ /^\-/) {
			$fmt{Z} = 0 - $z;
		} else {
			$fmt{Z} = $z;
		}
	}
	# c ISO 8601 日付 (PHP 5 で追加されました) 2004-02-12T15:19:21+00:00
	$fmt{c} = "$fmt{Y}-$fmt{m}-$fmt{d}T$fmt{H}:$fmt{i}:$fmt{s}$fmt{P}";
	# r RFC 2822 フォーマットされた日付 例: Thu, 21 Dec 2000 16:01:07 +0200 
	$fmt{r} = "$fmt{D}, $fmt{d} $fmt{M} $fmt{Y} $fmt{H}:$fmt{i}:$fmt{s} $fmt{O}";
	# U Unix Epoch (1970 年 1 月 1 日 0 時 0 分 0 秒) からの秒数 time() も参照
	$fmt{U} = $self->{time};
	#
	return %fmt;
}

sub get {
	my($self, $zero_pad) = @_;
	my($Y, $M, $D, $h, $m, $s, $w, $yday, $isdst, $timezone_offset, $tzloc);
	if( defined $self->{tz} && $self->{tz} ne "" ) {
		if($self->{tz} =~ /^([\+\-])(\d{2})(\d{2})/) {
			my $sign = $1;
			my $hour = $2 + 0;
			my $min  = $3 + 0;
			my $offset = $hour * 3600 + $min * 60;
			if($sign eq "-") {
				$offset = 0 - $offset;
			}
			($s, $m, $h, $D, $M, $Y, $w) = gmtime($self->{time} + $offset);
			$Y += 1900;
			$M ++;
			$isdst = 0;
			$timezone_offset = $self->{tz};
		} else {
			my $date = new Date::Handler({ date => $self->{time}, time_zone => $self->{tz}, locale => 'C'});
			$Y = $date->Year();
			$M = $date->Month();
			$D = $date->Day();
			$h = $date->Hour();
			$m = $date->Min();
			$s = $date->Sec();
			$w = $date->WeekDay();	# 1..7 (1 monday)
			if($w == 7) { $w = 0; }
			$isdst = $date->DayLightSavings();
			my $offset = $date->GmtOffset();
			my $sign = "+";
			if($offset < 0) { $sign = "-"; }
			$offset = abs($offset);
			$timezone_offset = $sign . sprintf("%02d", int( $offset / 3600 )) . sprintf("%02d", ($offset % 3600) / 60);
			$tzloc = $self->{tz};
		}
	} else {
		($s, $m, $h, $D, $M, $Y, $w, $yday, $isdst) = localtime($self->{time});
		$Y += 1900;
		$M ++;
		my($s2, $m2, $h2, $D2, $M2, $Y2) = gmtime($self->{time});
		$Y2 += 1900;
		$M2 ++;
		my($Dd,$Dh,$Dm,$Ds) = Date::Pcalc::Delta_DHMS($Y,$M,$D,$h,$m,$s, $Y2,$M2,$D2,$h2,$m2,$s2);
		$Dh = abs($Dh);
		$Dm = abs($Dm);
		$timezone_offset = sprintf("%02d", $Dh) . sprintf("%02d", $Dm);
		my $t1 = $Y . sprintf("%02d", $M) . sprintf("%02d", $D) . sprintf("%02d", $h) . sprintf("%02d", $m) . sprintf("%02d", $s);
		my $t2 = $Y2 . sprintf("%02d", $M2) . sprintf("%02d", $D2) . sprintf("%02d", $h2) . sprintf("%02d", $m2) . sprintf("%02d", $s2);
		$t1 += 0;
		$t2 += 0;
		if($t1 >= $t2) {
			$timezone_offset = "+" . $timezone_offset;
		} else {
			$timezone_offset = "-" . $timezone_offset;
		}
	}
	if($zero_pad) {
		$M = sprintf("%02d", $M);
		$D = sprintf("%02d", $D);
		$h = sprintf("%02d", $h);
		$m = sprintf("%02d", $m);
		$s = sprintf("%02d", $s);
	}
	return $Y, $M, $D, $h, $m, $s, $w, $isdst, $timezone_offset, $tzloc;
}

#--------------------------------------------------------------------

sub get_tz_offset_sec {
	my($self) = @_;
	my $now = time;
	my($timezone_offset, $tzloc);
	if( defined $self->{tz} && $self->{tz} ne "" ) {
		if($self->{tz} =~ /^([\+\-])(\d{2})(\d{2})/) {
			my $sign = $1;
			my $hour = $2 + 0;
			my $min  = $3 + 0;
			my $offset = $hour * 3600 + $min * 60;
			if($sign eq "-") {
				$offset = 0 - $offset;
			}
			return $offset;
		} else {
			my $date = new Date::Handler({ date => $now, time_zone => $self->{tz}, locale => 'C'});
			my $offset = $date->GmtOffset();
			return $offset;
		}
	} else {
		my($s, $m, $h, $D, $M, $Y) = localtime($now);
		$Y += 1900;
		$M ++;
		my($s2, $m2, $h2, $D2, $M2, $Y2) = gmtime($now);
		$Y2 += 1900;
		$M2 ++;
		my($Dd,$Dh,$Dm,$Ds) = Date::Pcalc::Delta_DHMS($Y,$M,$D,$h,$m,$s, $Y2,$M2,$D2,$h2,$m2,$s2);
		my $offset = $Dd*86400 + $Dh*3600 + $Dm*60 + $Ds;
		return $offset;
	}
}

1;
