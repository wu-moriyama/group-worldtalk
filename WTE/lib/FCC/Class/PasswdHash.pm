package FCC::Class::PasswdHash;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use Carp;
use Digest::SHA;

sub init {
	my($self, %args) = @_;
	#ストレッチング回数
	$self->{stretch_count} = 5000;
	if($args{stretch_count}) {
		$self->{stretch_count} = $args{stretch_count};
	}
	#Saltのバイト数
	$self->{salt_len} = 32;
	if($args{salt_len}) {
		$self->{salt_len} = $args{salt_len};
	}
}

#---------------------------------------------------------------------
#■ハッシュ化
#---------------------------------------------------------------------
#[引数]
#	1.パスワード文字列（必須）
#	2.ソルト (任意) 指定がなければ自動生成
#
#[戻り値]
#	ハッシュ化したパスワード
#---------------------------------------------------------------------
sub generate {
	my($self, $pass, $salt) = @_;
	unless($salt) {
		$salt = $self->generate_salt_hex();
	}
	my $ohash = Digest::SHA->new("sha256");
	my $phash = "";
	for(my $i=0; $i<$self->{stretch_count}; $i++) {
		$ohash->add($phash, $pass, $salt);
		$phash = $ohash->digest();
	}
	my $hash = $salt . unpack("H*", $phash);
	return $hash;
}

sub generate_salt_hex {
	my($self) = @_;
	my $slen = $self->{salt_len};
	my @hex_list;
	for(my $i=0; $i<$slen; $i++) {
		my $n = int(rand(256)); # 0 - 255
		my $h = sprintf("%02x", $n);
		push(@hex_list, $h);
	}
	my $salt_hex = join("", @hex_list);
	return $salt_hex;
}

#---------------------------------------------------------------------
#■検証
#---------------------------------------------------------------------
#[引数]
#	1.パスワード文字列（必須）
#	2.ハッシュ (必須)
#
#[戻り値]
#	OK なら 1 を、NG なら 0 を返す
#---------------------------------------------------------------------
sub validate {
	my($self, $pass, $hash) = @_;
	my $salt = substr($hash, 0, $self->{salt_len} * 2);
	my $hash2 = $self->generate($pass, $salt);
	return ($hash eq $hash2);
}

1;
