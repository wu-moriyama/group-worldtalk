package FCC::Class::Iprestriction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Net::Netmask;

sub init {
	my($self, %args) = @_;
	$self->{conf} = $args{conf};
}

#---------------------------------------------------------------------
#■IPアドレスがhosts.allowに一致するかどうかをチェック
#---------------------------------------------------------------------
#[引数]
#	1.IPアドレス（必須）
#[戻り値]
#	成功すれば結果を返す。一致すれば1を、一致しなければ0を返す。
#	失敗すればcroakする。
#---------------------------------------------------------------------
sub match {
	my($self, $ip) = @_;
	my $str;
	if($self->{conf}->{hosts_allow}) {
		$str = $self->{conf}->{hosts_allow};
	}
	if($str) {
		my @blocks = split(/\n+/, $str);
		for my $block (@blocks) {
			my $nm = new2 Net::Netmask($block);
			if($nm &&  Net::Netmask->new($block)->match($ip)) {
				return 1;
			}
		}
		return 0;
	} else {
		return 1;
	}
}

1;
