package FCC::Action::Admin::DctdelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dct;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dctlst");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Dctインスタンス
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#削除対象の識別ID
	my $dct_id = $self->{q}->param("dct_id");
	if( ! defined $dct_id || $dct_id eq "" || $dct_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $dct = $odct->del($dct_id);
	unless($dct) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: dct_id=${dct_id}"];
		return $context;
	}
	#プロセスセッションを削除
	$self->del_proc_session_data();
	#
	$context->{proc} = $proc;
	return $context;
}

1;
