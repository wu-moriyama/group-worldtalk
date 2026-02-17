package FCC::Action::Admin::CpnchgfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Coupon;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpnchg");
	#インスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#
	if($proc) {
		my $member_id = $proc->{in}->{member_id};
		my $member = $omember->get_from_db($member_id);
		while( my($k, $v) = each %{$member} ) {
			$proc->{in}->{$k} = $v;
		}
	} else {
		$proc = $self->create_proc_session_data("cpnchg");
		my $member_id = $self->{q}->param("member_id");
		my $member_caption = $self->{conf}->{member_caption};
		if( $member_id && $member_id =~ /^\d+$/ ) {
			my $member = $omember->get_from_db($member_id);
			if($member) {
				$proc->{in} = $member;
				if($member->{coupon_id}) {
					my $coupon_id = $member->{coupon_id};
					my $ocpn = new FCC::Class::Coupon(conf=>$self->{conf}, db=>$self->{db});
					my $cpn = $ocpn->get_from_db($coupon_id);
					if($cpn) {
						if($cpn->{coupon_available}) {
							while( my($k, $v) = each %{$cpn} ) {
								$proc->{in}->{$k} = $v;
							}
						} else {
							$context->{fatalerrs} = ["指定の${member_caption}に登録されたクーポン（coupon_id=${coupon_id}）が無効（有効期限切れなど）のため、チャージすることはできません。"];
							return $context;
						}
					} else {
						$context->{fatalerrs} = ["指定の${member_caption}はクーポンが登録されていないため、チャージすることはできません。"];
						return $context;
					}
				} else {
					$context->{fatalerrs} = ["指定の${member_caption}はクーポンが登録されていないため、チャージすることはできません。"];
					return $context;
				}
			} else {
				$context->{fatalerrs} = ["不正なリクエストです。"];
				return $context;
			}
		} else {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
	}
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}


1;
