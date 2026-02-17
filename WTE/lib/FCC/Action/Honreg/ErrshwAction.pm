package FCC::Action::Honreg::ErrshwAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Honreg::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	$context->{seller} = {};
	$context->{err} = 99;
	#代理店
	my $seller_id = $self->{q}->param("s");
	if($seller_id && $seller_id =~ /^\d+$/) {
		my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($seller_id);
		if($seller) {
			$context->{seller} = $seller;
		}
	}
	#エラーコード
	my $err = $self->{q}->param("err");
	$context->{err} = '不正なアクセスです。';
	if($err) {
		if($err eq "1") {
			$context->{err} = 'すでに本登録が完了しています。';
		}
	}
	#
	return $context;
}


1;
