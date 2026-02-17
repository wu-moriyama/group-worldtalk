package FCC::Action::Prof::ParentAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Ann;
use FCC::Class::Lesson;
use FCC::Class::Member;
use FCC::Class::Buzz;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	#���m�点���擾
	my $oann = new FCC::Class::Ann(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	my $ann_list = $oann->get_list_for_dashboard(3);
	#�{���̃��b�X���̈ꗗ���擾
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
	my $res1 = $olsn->get_list({
		prof_id     => $prof_id,
		lsn_etime_s => "$tm[0]$tm[1]$tm[2]$tm[3]$tm[4]",
		lsn_stime_e => "$tm[0]$tm[1]$tm[2]2359",
		lsn_cancel  => 0,
		offset      => 0,
		limit       => 999,
		sort        => [['lsn_stime', 'ASC']]
	});
	my $lsn_today_list = $res1->{list};
	#�����ȍ~�̃��b�X���̈ꗗ���擾
	my @tm2 = FCC::Class::Date::Utils->new(time=>time+86400, tz=>$self->{conf}->{tz})->get(1);
	my $res2 = $olsn->get_list({
		prof_id     => $prof_id,
		lsn_stime_s => "$tm2[0]$tm2[1]$tm2[2]0000",
		lsn_cancel  => 0,
		offset      => 0,
		limit       => 999,
		sort        => [['lsn_stime', 'ASC']]
	});
	my $lsn_tomorrow_list = $res2->{list};
	#�I���������b�X���̈ꗗ���擾
	my $res3 = $olsn->get_list({
		prof_id     => $prof_id,
		lsn_etime_e => "$tm[0]$tm[1]$tm[2]$tm[3]$tm[4]",
		lsn_cancel  => 0,
		offset      => 0,
		limit       => 5,
		sort        => [['lsn_stime', 'DESC']]
	});
	my $lsn_finished_list = $res3->{list};
	#�N�`�R�~�̈ꗗ���擾
	my $buz_res = FCC::Class::Buzz->new(conf=>$self->{conf}, db=>$self->{db})->get_list({
		prof_id     => $prof_id,
		offset      => 0,
		limit       => 5,
		sort        => [['buz_id', 'DESC']]
	});
	my $buz_list = $buz_res->{list};
	#��������擾
	my %member_id_hash;
	for my $lsn (@{$lsn_today_list}) {
		$member_id_hash{$lsn->{member_id}} = 1;
	}
	for my $lsn (@{$lsn_tomorrow_list}) {
		$member_id_hash{$lsn->{member_id}} = 1;
	}
	for my $lsn (@{$lsn_finished_list}) {
		$member_id_hash{$lsn->{member_id}} = 1;
	}
	my $members = {};
	my $omem = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	for my $member_id (keys %member_id_hash) {
		$members->{$member_id} = $omem->get($member_id);
	}
	#
	$context->{ann_list} = $ann_list;
	$context->{lsn_today_list} = $lsn_today_list;
	$context->{lsn_tomorrow_list} = $lsn_tomorrow_list;
	$context->{lsn_finished_list} = $lsn_finished_list;
	$context->{buz_list} = $buz_list;
	$context->{members} = $members;
	return $context;
}

1;
