package FCC::Action::Mypage::MbrmodfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrmod");
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	#インスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#
	if($proc) {
		if( $proc->{in}->{member_logo_updated} != 1 ) {
			if(  $proc->{in}->{member_logo_up} || $proc->{in}->{member_logo_del} eq "1" ) {
				$proc->{in}->{member_logo_updated} = 1;
			} else {
				#会員情報を取得
				my $member_orig = $omember->get_from_db($proc->{in}->{member_id});
				#オリジナルのmember_logoをセット
				$proc->{in}->{member_logo} = $member_orig->{member_logo};
			}
		}
	} else {
		if( ! defined $member_id || $member_id eq "" || $member_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("mbrmod");
		#会員情報を取得
		my $member = $omember->get_from_db($member_id);
		unless($member) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		delete $member->{member_pass};
		$proc->{in} = $member;
		$proc->{in}->{member_logo_updated} = 0;
		#代理店識別IDを取得
		my $seller_id = $member->{seller_id};
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}

1;
