#---------------------------------------------------------------------#
#■文字列チェックモジュール
#
#・使い方
#
#	my $sc = new FCC::Class::String::Checker($str, $icode);
#
#	$icodeは'utf8', 'sjis', 'euc'のいずれかを指定すること。
#	指定がなければ'utf8'と見なします。
#
#	#郵便番号チェック
#	if( $sc->is_zip() ) {...}
#	#電話番号チェック
#	if( $sc->is_tel() ) {...}
#	#URLチェック
#	if( $sc->is_url() ) {...}
#	#メールアドレスチェック
#	if( $sc->is_mailaddress() ) {...}
#
#	#全角ひらがな判定
#	if( $sc->is_hira_zen() ) {...}
#	#全角カタカナ判定
#	if( $sc->is_kana_zen() ) {...}
#
#	#文字数を返す
#	my $n = $sc->get_char_num();
#	#文字を配列で返す
#	my @chars = $sc->split_to_chars();
#---------------------------------------------------------------------#

package FCC::Class::String::Checker;
$VERSION = 1.00;
use strict;
use warnings;
use Unicode::Japanese;

sub new {
	my($caller, $str, $icode) = @_;
	my $class = ref($caller) || $caller;
	my $self = {};
	unless(defined $str) { $str = ''; }
	unless(defined $icode) { $icode = ''; }
	$self->{str} = $str;
	$self->{icode} = $icode;
	unless($icode =~ /^(utf8|sjis|euc)$/) {
		$self->{icode} = 'utf8';
	}
	bless $self, $class;
	return $self;
}

sub get_char_num {
	my($self, $str) = @_;
	$str = $self->_get_utf8_str($str);
	my @chars;
	eval { require Encode; };
	if($@) {
		use utf8;
		@chars = split(//, $str);
	} else {
		$str = Encode::decode("utf-8", $str);
		@chars = split(//, $str);
	}
	my $n = scalar @chars;
	return $n;
}

sub split_to_chars {
	my($self, $str) = @_;
	$str = $self->_get_utf8_str($str);
	my @chars;
	eval { require Encode; };
	if($@) {
		use utf8;
		@chars = split(//, $str);
	} else {
		$str = Encode::decode("utf-8", $str);
		@chars = split(//, $str);
		for( my $i=0; $i<@chars; $i++ ) {
			my $char = $chars[$i];
			$char = Encode::encode("utf-8", $char);
			$chars[$i] = $char;
		}
	}
	my $icode = $self->{icode};
	if($icode ne 'utf8') {
		for( my $i=0; $i<@chars; $i++ ) {
			my $c = $chars[$i];
			$chars[$i] = Unicode::Japanese->new($c,'utf8')->conv($icode);
		}
	}
	return @chars;
}

#---------------------------------------------------------------------
#全角ひらがな
#	　	E38080
#	、	E38081
#	。	E38082
#	～	E3809C
#	～	EFBD9E
#	－	E28892	マイナス
#	―	E28095	ダッシュ
#	‐	E28090	ハイフン
#---------------------------------------------------------------------
sub is_hira_zen {
	my($self, $str) = @_;
	$str = $self->_get_utf8_str($str);
	my $tmp = $str;
	$tmp =~ s/\xe3((\x81[\x81-\xBF])|(\x82[\x80-\x93]))//g;
	$tmp =~ s/\xe3(\x80([\x80-\x82]|\x9C))//g;
	$tmp =~ s/(\xEF\xBD\x9E|\xE2\x88\x92|\xE2\x80\x95|\xE2\x80\x90)//g;
	if($tmp ne '') {
		return 0;
	} else {
		return 1;
	}
}

#---------------------------------------------------------------------
#全角カタカナ
#	　	E38080
#	、	E38081
#	。	E38082
#	～	E3809C
#	～	EFBD9E
#	－	E28892	マイナス
#	―	E28095	ダッシュ
#	‐	E28090	ハイフン
#---------------------------------------------------------------------
sub is_kana_zen {
	my($self, $str) = @_;
	$str = $self->_get_utf8_str($str);
	my $tmp = $str;
	$tmp =~ s/\xe3((\x82[\xA1-\xBF])|(\x83[\x80-\xB6]))//g;
	$tmp =~ s/\xe3(\x80([\x80-\x82]|\x9C))//g;
	$tmp =~ s/(\xEF\xBD\x9E|\xE2\x88\x92|\xE2\x80\x95|\xE2\x80\x90)//g;
	if($tmp ne '') {
		return 0;
	} else {
		return 1;
	}
}

sub is_zip {
	my($self, $zip) = @_;
	unless($zip) { $zip = $self->{str}; }
	#まずは、半角数字と半角ハイフン以外の
	#文字が含まれていないかをチェック
	if($zip =~ /[^0-9\-]/) {
		return 0;
	}
	#半角ハイフンを取り除く
	$zip =~ s/\-//g;
	#フォーマットチェック
	if($zip =~ /^\d{7}$/) {
		return 1;
	} else {
		return 0;
	}
}

sub is_tel {
	my($self, $tel) = @_;
	unless($tel) { $tel = $self->{str}; }
	#まずは、半角数字と半角ハイフン以外の
	#文字が含まれていないかをチェック
	if($tel =~ /[^0-9\-]/) {
		return 0;
	}
	#半角ハイフンを取り除く
	$tel =~ s/\-//g;
	#数字の桁数を調べる
	my $len = length $tel;
	#各電話サービスごとに条件分岐
	if($tel =~ /^0(5|7|8|9)0[1-9]/) {
	#携帯電話、PHSの場合
		if($len == 11) {
		  return 1;
		} else {
		  return 0;
		}
	} elsif($tel =~ /^0120/) {
	#着信課金用電話番号の場合
		if($len == 10) {
		  return 1;
		} else {
		  return 0;
		}
	} elsif($tel =~ /^0800/) {
	#着信課金用電話番号の場合
		if($len == 11) {
		  return 1;
		} else {
		  return 0;
		}
	} elsif($tel =~ /^0[1-9]{2}/) {
	#固定電話の場合
		if($len == 9 || $len == 10) {
		  return 1;
		} else {
		  return 0;
		}
	} else {
	#以上すべてに当てはまらない場合
		return 0;
	}
}

sub is_url {
	my($self, $url) = @_;
	unless($url) { $url = $self->{str}; }
	unless($url =~ /^https*:\/\/[^\/]+/) {
		return 0;
	}
	if($url =~ /[^0-9a-zA-Z\:\/\.\-\_\#\%\&\=\~\+\?]/) {
		return 0;
	}
	return 1;
}

sub is_mailaddress {
	my($self, $mail) = @_;
	unless($mail) { $mail = $self->{str}; }
	#チェック1（不適切な文字をチェック）
	if($mail =~ /[^a-zA-Z0-9\@\.\-\_\#\$\%]/) {
		return 0;
	}
	#チェック2（@マークのチェック）
	#"@"の数を数えます。1つ以外だった場合には0を返す
	my $at_num = 0;
	while($mail =~ /\@/g) {
		$at_num ++;
	}
	if($at_num != 1) {
		return 0;
	}
	#チェック3（アカウント、ドメインの存在をチェック）
	my($acnt, $domain) = split(/\@/, $mail);
	if($acnt eq '' || $domain eq '') {
		return 0;
	}
	#チェック4（ドメインのドットをチェック）
	#ドットの数を数えます。0個だった場合には0を返す
	my $dot_num = 0;
	while($domain =~ /\./g) {
		$dot_num ++;
	}
	if($dot_num == 0) {
		return 0;
	}
	#チェック5（ドメインの各パーツをチェック）
	#先頭にドットがないことをチェック
	if($domain =~ /^\./) {
		return 0;
	}
	#最後にドットがないことをチェック
	if($domain =~ /\.$/) {
		return 0;
	}
	#ドットが2つ以上続いていないかをチェック
	if($domain =~ /\.\./) {
		return 0;
	}
	#チェック6（TLDのチェック）
	my @domain_parts = split(/\./, $domain);
	my $tld = pop @domain_parts;
	if($tld =~ /[^a-zA-Z]/) {
		return 0;
	}
	#すべてのチェックが通ったので、
	#このメールアドレスは適切である
	return 1;
}

######################################################################

sub _get_utf8_str {
	my($self, $str) = @_;
	unless($str) { $str = $self->{str}; }
	my $icode = $self->{icode};
	if($icode ne 'utf8') {
		$str = Unicode::Japanese->new($str,$icode)->get;
	}
	return $str;
}

1;
