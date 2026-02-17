package FCC::Action::Site::PrfdtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Site::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::Buzz;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#講師識別IDを取得
	my $prof_id = $self->{q}->param("prof_id");
	unless($prof_id) {
		if( $self->{conf}->{CGI_URL_PATH} =~ /\/prfdtlfrm\/(\d+)/i ) {
			$prof_id = $1;
		}
	}
	if( ! defined $prof_id || $prof_id eq "" || $prof_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#会員ログイン済みなら会員メニューへリダイレクト
	if( $self->{session}->{data} && $self->{session}->{data}->{member_id} ) {
		$context->{redirect} = $self->{conf}->{ssl_host_url} . "/WTE/mypage.cgi?m=prfdtlfrm&prof_id=${prof_id}";
		return $context;
	}
	#講師情報を取得
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db});
	my $prof = $oprof->get_from_db($prof_id);
	if( ! $prof || $prof->{prof_status} != 1 ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#国選択肢リスト
	my $country_hash = $oprof->get_prof_country_hash();
	if($prof->{prof_country}) {
		$prof->{prof_country_name} = $country_hash->{$prof->{prof_country}};
	}
	if($prof->{prof_residence}) {
		$prof->{prof_residence_name} = $country_hash->{$prof->{prof_residence}};
	}
	#クチコミを取得
	my $obuz = new FCC::Class::Buzz(conf=>$self->{conf}, db=>$self->{db});
	my $buz_res = $obuz->get_list({
		prof_id => $prof_id,
		buz_show => 1,
		offset => 0,
		limit => 100,
		sort   => [["buz_id", "DESC"]]
	});
	my $buz_list = $buz_res->{list};
	#
	$context->{prof} = $prof;
	$context->{buz_list} = $buz_list;
	return $context;
}


1;
