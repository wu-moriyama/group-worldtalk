package FCC::Action::Admin::LsnmodsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Lesson;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "lsnmod");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'lsn_status'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $lsn = $proc->{lsn};
		my $lsn_id = $lsn->{lsn_id};
		my $lsn_status = $proc->{in}->{lsn_status};
		my $olsn = new FCC::Class::Lesson(conf=>$self->{conf}, db=>$self->{db});
		my $new_lsn = $olsn->update_status($lsn_id, $lsn_status, $lsn);
		$proc->{lsn} = $new_lsn;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $names, $in) = @_;
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		#ステータス
		if($k eq "lsn_status") {
			if($v eq "") {
				push(@errs, [$k, "\"ステータス\" は必須です。"]);
			} elsif($v !~ /^(0|1|11|12|13|21|22|23|29)$/) {
				push(@errs, [$k, "\"ステータス\" に不正な値が送信されました。"]);
			}
		}
	}
	return @errs;
}

1;
