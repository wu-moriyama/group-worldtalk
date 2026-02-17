package FCC::Action::Admin::DctaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dct;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dctadd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'dct_title',
		'dct_status'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	# FCC:Class::Dctインスタンス
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#入力値チェック
	my @errs = $odct->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $dct = $odct->add($proc->{in});
		$proc->{dct} = $dct;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
