package FCC::Action::Mypage::FavsetajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Fav;
use FCC::Class::Prof;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#prof_id
	my $prof_id = $self->{q}->param("prof_id");
	if( ! $prof_id || $prof_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["bad request"];
		return $context;
	}
	#指定の講師情報を取得
	my $prof = FCC::Class::Prof->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get($prof_id);
	if( ! $prof || $prof->{prof_status} != 1 ) {
		$context->{fatalerrs} = ["bad request"];
		return $context;
	}
	#お気に入りの登録数をチェック
	my $ofav = new FCC::Class::Fav(conf=>$self->{conf}, db=>$self->{db});
	my $num = $ofav->get_member_fav_num($member_id);
	if($num >= $self->{conf}->{member_fav_limit}) {
		$context->{fatalerrs} = ["limit over"];
		return $context;
	}
	#指定の講師がすでにお気に入りかどうかをチェック
	my $fav = $ofav->get_from_member_prof_id($member_id, $prof_id);


	#登録処理
	my $return_value = 0;
	if($fav) {
		$ofav->del($fav->{fav_id});
		$return_value = 0;
	} else {
		$ofav->add({
			member_id => $member_id,
			prof_id   => $prof_id
		});
		$return_value = 1;
	}
	#
	$context->{return_value} = $return_value;
	return $context;
}

1;
