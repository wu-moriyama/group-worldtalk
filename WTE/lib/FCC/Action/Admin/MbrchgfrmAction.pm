package FCC::Action::Admin::MbrchgfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Lesson;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrchg");
	#インスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db});
	#
	if($proc) {
		my $member_id = $proc->{in}->{member_id};
		my $member = $omember->get_from_db($member_id);
		while( my($k, $v) = each %{$member} ) {
			$proc->{in}->{$k} = $v;
		}
	} else {
		$proc = $self->create_proc_session_data("mbrchg");
		my $member_id = $self->{q}->param("member_id");
		if( defined $member_id && $member_id !~ /[^\d]/ ) {
			my $member = $omember->get_from_db($member_id);
			if($member) {
				$proc->{in} = $member;
				$proc->{in}->{mbract_reason} = 43;
				#
				my $epoch = time + (86400 * $self->{conf}->{point_expire_days});
				my @tm = FCC::Class::Date::Utils->new(time=>$epoch, tz=>$self->{conf}->{tz})->get(1);
				$proc->{in}->{member_point_expire_update} = "$tm[0]-$tm[1]-$tm[2]";
				#
				my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
				$proc->{in}->{member_receivable_point} = $olsn->get_receivable($member_id, 1); # ポイントの売り掛け
				$proc->{in}->{member_available_point} = $member->{member_point} - $proc->{in}->{member_receivable_point}; # 実質的に利用可能なポイント
				if($proc->{in}->{member_available_point} < 0) {
					$proc->{in}->{member_available_point} = 0;
				}
			}
		}
	}
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}


1;
