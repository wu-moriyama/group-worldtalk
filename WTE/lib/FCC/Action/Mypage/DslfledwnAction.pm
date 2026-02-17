package FCC::Action::Mypage::DslfledwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Dwnsel;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#識別IDを取得
	my $dsl_id = $self->{q}->param("dsl_id");
	if( ! defined $dsl_id || $dsl_id eq "" || $dsl_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#情報を取得
	my $odsl = new FCC::Class::Dwnsel(conf=>$self->{conf}, db=>$self->{db});
	my $dsl = $odsl->get($dsl_id);
	if( ! $dsl ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	} elsif( ! $dsl->{dsl_qualified} ) {
		$context->{fatalerrs} = ["有効期限が過ぎたためご利用になれません。"];
		return $context;
	}
	#
	if($dsl->{dwn_loc} == 1) {
		$dsl->{dwn_fpath} = $self->{conf}->{dwn_file_dir} . "/" . $dsl->{dwn_id} . ".dat";
		unless( -e $dsl->{dwn_fpath} ) {
			$context->{fatalerrs} = ["商品ファイルが登録されていないためダウンロードできません。"];
			return $context;
		}
		$dsl->{dwn_fsize} = -s $dsl->{dwn_fpath};
	}
	#
	$context->{dsl} = $dsl;
	return $context;
}


1;
