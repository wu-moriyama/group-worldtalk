package FCC::Action::Mypage::BnkcfmsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;
use FCC::Class::Plan;
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "bnk");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'pln_id',
		'kana',
		'date',
		'note'
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
		my $opln = new FCC::Class::Plan(conf=>$self->{conf}, db=>$self->{db});
		my $pln = $opln->get($in->{pln_id});
		if($pln) {
			$proc->{in}->{confirm_ok} = 1;
			while( my($k, $v) = each %{$pln} ) {
				$proc->{in}->{$k} = $v;
			}
		} else {
			push(@errs, ["pln_id", "不正な値が送信されました。"]);
		}
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $names, $in) = @_;
	my %cap = (
		pln_id => "プラン",
		kana  => "お振込名（カナ）",
		date  => "お振込予定日",
		note  => "備考"
	);
	#入力値のチェック
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#ポイント
		if($k eq "pln_id") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			}
		#お振込名（カナ）
		} elsif($k eq "kana") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 50) {
				push(@errs, [$k, "\"$cap{$k}\" は50文字以内で入力してください。"]);
			}
		#お振込予定日
		} elsif($k eq "date") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 50) {
				push(@errs, [$k, "\"$cap{$k}\" は50文字以内で入力してください。"]);
			}
		#備考
		} elsif($k eq "note") {
			if($v eq "") {
				#push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 3000) {
				push(@errs, [$k, "\"$cap{$k}\" は3000文字以内で入力してください。"]);
			}
		}
	}
	#
	return @errs;
}

1;
