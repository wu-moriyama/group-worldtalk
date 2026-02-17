package FCC::Action::Mypage::InqcfmsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "inq");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'inq_title',
		'inq_cont'
	];
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#ラジオボタンとセレクトメニューの値のリスト
	my @names = $self->{q}->param();
	my $captions = {};
	for my $name (@names) {
		if($name =~ /_caption_\d+$/) {
			$captions->{$name} = $self->{q}->param($name);
		}
	}
	$proc->{captions} = $captions;
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in}, $captions);
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		$proc->{in}->{confirm_ok} = 1;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $names, $in, $captions) = @_;
	my %cap = (
		inq_title => "お問い合わせ項目",
		inq_cont => "お問い合わせ内容"
	);
	#入力値のチェック
	my @errs;
	for my $k (@{$names}) {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $len = FCC::Class::String::Checker->new($v, "utf8")->get_char_num();
		#お問い合わせ項目
		if($k eq "inq_title") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($v =~ /[^\d]/ || !$captions->{"${k}_caption_${v}"}) {
				push(@errs, [$k, "\"$cap{$k}\" に不正な値が送信されました。"]);
			}
		#お問い合わせ内容
		} elsif($k eq "inq_cont") {
			if($v eq "") {
				push(@errs, [$k, "\"$cap{$k}\" は必須です。"]);
			} elsif($len > 3000) {
				push(@errs, [$k, "\"$cap{$k}\" は3000文字以内で入力してください。"]);
			}
		}
	}
	#
	return @errs;
}

1;
