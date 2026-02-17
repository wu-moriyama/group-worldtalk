package FCC::Action::Admin::AnndelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Ann;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "anndel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Annインスタンス
	my $oann = new FCC::Class::Ann(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#削除対象の識別ID
	my $ann_id = $proc->{in}->{ann_id};
	if( ! defined $ann_id || $ann_id eq "" || $ann_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $ann = $oann->del($ann_id);
	unless($ann) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: ann_id=${ann_id}"];
		return $context;
	}
	$proc->{in} = $ann;
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
