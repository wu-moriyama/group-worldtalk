package FCC::Action::Admin::MbrchgcptAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbrchg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#会員情報
	my $member_id = $proc->{in}->{member_id};
	my $data = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db})->get_from_db($member_id);
	#入力値情報
	while( my($k, $v) = each %{$proc->{in}} ) {
		$data->{$k} = $v;
	}
	#セッション削除
	$self->del_proc_session_data();
	#
	$context->{data} = $data;
	return $context;
}

1;
