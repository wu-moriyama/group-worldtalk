package FCC::Action::Admin::SeldelfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "seldel");
	unless($proc) {
		my $seller_id = $self->{q}->param("seller_id");
		if( ! defined $seller_id || $seller_id eq "" || $seller_id =~ /[^\d]/ ) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		$proc = $self->create_proc_session_data("seldel");
		#インスタンス
		my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		#代理店情報を取得
		my $seller = $oseller->get_from_db($seller_id);
		unless($seller) {
			$context->{fatalerrs} = ["不正なリクエストです。"];
			return $context;
		}
		#会員数を取得
		my $member_num_hash = $oseller->count_member_num([$seller_id]);
		$seller->{member_num} = $member_num_hash->{$seller_id} + 0;
		if($seller->{member_num} > 0) {
			$context->{fatalerrs} = ["会員が登録された代理店を削除することはできません。"];
			return $context;
		}
		#
		$proc->{in} = $seller;
		$self->set_proc_session_data($proc);
	}
	$context->{proc} = $proc;
	return $context;
}


1;
