package FCC::Action::Admin::DwnfledwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#識別IDを取得
	my $dwn_id = $self->{q}->param("dwn_id");
	if( ! defined $dwn_id || $dwn_id eq "" || $dwn_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#インスタンス
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db});
	#情報を取得
	my $dwn = $odwn->get($dwn_id);
	unless($dwn) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	if($dwn->{dwn_loc} != 1) {
		$context->{fatalerrs} = ["商品保存場所がローカルでない商品はダウンロードできません。"];
		return $context;
	}
	$dwn->{dwn_fpath} = $self->{conf}->{dwn_file_dir} . "/" . $dwn_id . ".dat";
	unless( -e $dwn->{dwn_fpath} ) {
		$context->{fatalerrs} = ["商品ファイルが登録されていないためダウンロードできません。"];
		return $context;
	}
	$dwn->{dwn_fsize} = -s $dwn->{dwn_fpath};
	#
	$context->{dwn} = $dwn;
	return $context;
}


1;
