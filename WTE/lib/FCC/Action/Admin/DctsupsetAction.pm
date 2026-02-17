package FCC::Action::Admin::DctsupsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dct;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#識別ID
	my $dct_id = $self->{q}->param("dct_id");
	if( ! $dct_id || $dct_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Dctインスタンス
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#表示順を上げる
	my $sort_num = $odct->sort_up($dct_id);
	#
	return $context;
}

1;
