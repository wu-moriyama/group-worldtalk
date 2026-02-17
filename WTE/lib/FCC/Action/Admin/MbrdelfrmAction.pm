package FCC::Action::Admin::MbrdelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrdel");
	unless($proc) {
		$proc = $self->create_proc_session_data("mbrdel");
		#会員識別IDを取得
		my $member_id = $self->{q}->param("member_id");
		if( ! defined $member_id || $member_id eq "" || $member_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#インスタンス
		my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db});
		#会員情報を取得
		my $member = $omember->get_from_db($member_id);
		unless($member) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc->{member} = $member;
		#代理店識別IDを取得
		my $seller_id = $member->{seller_id};
		#代理店情報を取得
		my $seller = FCC::Class::Seller->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($seller_id);
		$proc->{seller} = $seller;
		#
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
