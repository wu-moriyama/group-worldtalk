package FCC::Class::Log;
$VERSION = 1.00;
use strict;
use base qw(FCC::_Super);
use FCC::Class::Date::Utils;

sub init {
	my($self, %args) = @_;
	$self->{conf} = $args{conf};
	$self->{dir} = "$args{conf}->{BASE_DIR}/data/logs";
	unless(-d $self->{dir}) {
		mkdir $self->{dir}, 0777;
		chmod 0777, $self->{dir};
	}
}

sub loging {
	my($self, $log_level, $msg) = @_;
	$msg =~ s/\n+//g;
	$msg =~ s/\r+//g;
	#現在日時
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $now = "$tm[0]-$tm[1]-$tm[2] $tm[3]:$tm[4]:$tm[5]";
	#ログファイル
	my $f = "$self->{dir}/$self->{conf}->{FCC_SELECTOR}.$tm[0]$tm[1]$tm[2].log";
	#IPアドレス
	my $ip = $ENV{REMOTE_ADDR};
	#ログ文字列
	my $line = "${now} ${ip} \[${log_level}\] ${msg}";
	#ログファイルへ書き込み
	open(LOG, ">>${f}");
	print LOG ${line}, "\n";
	close(LOG);
	#パーミッションを666に
	chmod 0666, ${f};
}

1;
