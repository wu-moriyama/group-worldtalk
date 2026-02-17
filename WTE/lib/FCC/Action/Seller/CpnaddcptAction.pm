package FCC::Action::Seller::CpnaddcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);

sub dispatch {
	my($self) = @_;
	my $context = {};
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	#プロセスセッションデータをコピー
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpnadd");
	my $in = {};
	while( my($k, $v) = each %{$proc->{coupon}} ) {
		$in->{$k} = $v;
	}
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#
	$context->{in} = $in;
	return $context;
}

1;
