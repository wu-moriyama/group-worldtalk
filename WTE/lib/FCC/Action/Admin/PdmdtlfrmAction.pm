package FCC::Action::Admin::PdmdtlfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;
use FCC::Class::Pdm;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#識別IDを取得
	my $pdm_id = $self->{q}->param("pdm_id");
	if( ! defined $pdm_id || $pdm_id eq "" || $pdm_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#情報を取得
	my $opdm = new FCC::Class::Pdm(conf=>$self->{conf}, db=>$self->{db});
	my $pdm = $opdm->get($pdm_id);
	if( ! $pdm ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#レッスン情報を取得
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $res = $olsn->get_list({
		pdm_id => $pdm_id,
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
	$context->{pdm} = $pdm;
	$context->{lsn_list} = $lsn_list;
	return $context;
}


1;
