package FCC::Action::Seller::SelmodsetAction;
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
	my $proc = $self->get_proc_session_data($pkey, "selmod");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'seller_name',
		'seller_email',
		'seller_company',
		'seller_dept',
		'seller_title',
		'seller_lastname',
		'seller_firstname',
		'seller_zip1',
		'seller_zip2',
		'seller_addr1',
		'seller_addr2',
		'seller_addr3',
		'seller_addr4',
		'seller_tel1',
		'seller_tel2',
		'seller_tel3',
		'seller_url'
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
		$proc->{in} = $seller;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
