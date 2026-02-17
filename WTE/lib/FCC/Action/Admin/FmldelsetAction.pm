package FCC::Action::Admin::FmldelsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Fml;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "fmldel");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	# FCC:Class::Fmlインスタンス
	my $ofml = new FCC::Class::Fml(conf=>$self->{conf}, db=>$self->{db});
	#削除対象の識別ID
	my $fml_id = $proc->{in}->{fml_id};
	if( ! defined $fml_id || $fml_id eq "" || $fml_id =~ /[^\d]/ ) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#削除処理
	$proc->{errs} = [];
	my $fml = $ofml->del($fml_id);
	unless($fml) {
		$context->{fatalerrs} = ["対象のレコードは登録されておりません。: fml_id=${fml_id}"];
		return $context;
	}
	$proc->{in} = $fml_id;
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
