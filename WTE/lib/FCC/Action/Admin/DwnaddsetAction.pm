package FCC::Action::Admin::DwnaddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwnadd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'dwn_title',
		'dct_id',
		'dwn_type',
		'dwn_loc',
		'dwn_url',
		'dwn_point',
		'dwn_weight',
		'dwn_logo',
		'dwn_period',
		'dwn_duration',
		'dwn_intro',
		'dwn_note',
		'dwn_logo_up',
		'dwn_logo_del'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	# FCC:Class::Dwnインスタンス
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値チェック
	my @errs = $odwn->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $dwn = $odwn->add($proc->{in});
		$proc->{in} = $dwn;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
