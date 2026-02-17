package FCC::Action::Seller::NtemodsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use FCC::Class::Seller;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "ntemod");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'seller_note'
	];
	# FCC:Class::Sellerインスタンス
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs = $oseller->input_check($in_names, $proc->{in}, "mod");
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $seller = $oseller->mod($proc->{in});
		$proc->{in}->{seller_note} = $seller->{seller_note};
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
