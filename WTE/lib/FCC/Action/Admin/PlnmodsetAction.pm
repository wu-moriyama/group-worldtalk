package FCC::Action::Admin::PlnmodsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Plan;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "plnmod");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [];
	my @names = ("pln_id", "pln_title", "pln_subscription", "pln_price", "pln_point", "pln_status", "pln_sort");
	for( my $i=1; $i<=$self->{conf}->{plan_max}; $i++ ) {
		for my $k (@names) {
			push(@{$in_names}, "${k}_${i}");
		}
	}
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $list = [];
	for( my $i=1; $i<=$self->{conf}->{plan_max}; $i++ ) {
		my $h = { i => $i };
		for my $k (@names) {
			$h->{$k} = $in->{"${k}_${i}"};
		}
		push(@{$list}, $h);
	}
	$proc->{in} = $list;
	#入力値チェック
	my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
	my $ids = {};
	my @errs;
#	for( my $i=1; $i<=$self->{conf}->{plan_max}; $i++ ) {
	for( my $i=0; $i<@{$list}; $i++ ) {
		my $pln = $list->[$i];
		unless( $pln ) { next; }
		my $pln_id = $pln->{pln_id};
		unless( $pln_id ) { next; }
		if( $ids->{$pln_id} ) {
			my $n = $i + 1;
			push(@errs, ["plan_id_${n}", "商品コードが重複しています。"]);
			last;
		}
		$ids->{$pln_id} = 1;
		@errs = $opln->input_check(\@names, $list->[$i]);
		if(@errs) {
			for my $e (@errs) {
				$e->[0] = $e->[0] . "_" . $i;
			}
			last;
		}
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my @rec_list;
		for my $r (@{$proc->{in}}) {
			unless($r->{pln_id}) { next; }
			push(@rec_list, $r);
		}
		my @sorted = sort { $a->{pln_sort} <=> $b->{pln_sort} } @rec_list;
		my $new_list = $opln->set(\@sorted);
		$proc->{in} = $new_list;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
