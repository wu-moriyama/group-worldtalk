package FCC::Action::Admin::SdmdtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Sdm;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#識別IDを取得
	my $sdm_id = $self->{q}->param("sdm_id");
	if( ! defined $sdm_id || $sdm_id eq "" || $sdm_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#情報を取得
	my $osdm = new FCC::Class::Sdm(conf=>$self->{conf}, db=>$self->{db});
	my $sdm = $osdm->get($sdm_id);
	if( ! $sdm ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#レッスン情報を取得
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $res = $olsn->get_list({
		sdm_id => $sdm_id,
		offset => 0,
		limit  => 1000
	});
	my $lsn_list = $res->{list};
	#会員情報を取得
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $members = {};
	my $member_id_list = [];
	for my $ref (@{$lsn_list}) {
		my $member = $members->{$ref->{member_id}};
		unless($member) {
			$member = $omember->get($ref->{member_id});
			if($member) {
				$members->{$ref->{member_id}} = $member;
			}
		}
		unless($member) { next; }
		while( my($k, $v) = each %{$member} ) {
			$ref->{$k} = $v;
		}
	}
	#
	$context->{sdm} = $sdm;
	$context->{lsn_list} = $lsn_list;
	return $context;
}


1;
