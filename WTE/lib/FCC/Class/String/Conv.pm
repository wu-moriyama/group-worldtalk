#---------------------------------------------------------------------#
#■文字列変換モジュール
#
#・使い方
#
#	my $sc = new FCC::Class::String::Conv($str, $icode);
#
#	$icodeは'utf8', 'sjis', 'euc'のいずれかを指定すること。
#	指定がなければ自動判別となります。
#
#	#HTMLサニタイズ
#	$html = $sc->html_sanitize();
#
#	#文字切抜き
#	$str = $sc->truncate_chars($offset, $len);
#
#	#数字にカンマを挿入
#	$str = $sc->comma_format();
#---------------------------------------------------------------------#

package FCC::Class::String::Conv;
$VERSION = 1.00;
use strict;
use warnings;
use FCC::Class::String::Checker;

sub new {
	my($caller, $str, $icode) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	unless(defined $str) { $str = ''; }
	unless(defined $icode) { $icode = ''; }
	$self->{str} = $str;
	$self->{icode} = $icode;
	unless($icode =~ /^(utf8|sjis|euc)$/) {
		$self->{icode} = '';
	}
	bless $self, $class;
	return $self;
}

sub html_sanitize {
	my($self) = @_;
	my $str = $self->{str};
	eval { require HTML::Scrubber; };
	if($@) {
		$str =~ s/</&lt;/g;
		$str =~ s/>/&gt;/g;
		return $str;
	} else {
		my $scrubber = HTML::Scrubber->new( allow => [] );
		return $scrubber->scrub($str);
	}
}

sub truncate_chars {
	my($self, $offset, $len) = @_;
	my $str = $self->{str};
	my $icode = $self->{icode};
	my @chars = new FCC::Class::String::Checker($str, $icode)->split_to_chars();
	my @cutted = splice(@chars, $offset, $len);
	return join("", @cutted);
}

sub comma_format {
	my($self) = @_;
	my $num = $self->{str};
	unless($num) { return $num; }
	#数字とドット以外の文字が含まれていたら、
	#引数をそのまま返す
	if($num =~ /[^0-9\.]/) {return $num;}
	#整数部分と小数点を分離
	my($int, $decimal) = split(/\./, $num);
	#整数部分の桁数を調べる
	my $figure = length $int;
	my $commaformat = '';
	#整数部分にカンマを挿入
	for(my $i=1;$i<=$figure;$i++) {
	   my $n = substr($int, $figure-$i, 1);
	   if(($i-1) % 3 == 0 && $i != 1) {
	      $commaformat = "$n,$commaformat";
	   } else {
	      $commaformat = "$n$commaformat";
	   }
	}
	#小数点があれば、それを加える
	if($decimal) {
	   $commaformat .= "\.$decimal";
	}
	#結果を返す
	return $commaformat;
}

1;
