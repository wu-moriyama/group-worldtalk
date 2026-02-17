package FCC::Action::Prof::PasswdsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Prof::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::PasswdHash;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "passwd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'prof_pass',
		'prof_pass_new1',
		'prof_pass_new2'
	];
	# FCC:Class::Profインスタンス
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#講師情報を取得
	my $prof_id = $self->{session}->{data}->{prof}->{prof_id};
	my $prof = $oprof->get_from_db($prof_id);
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in}, $prof);
	#
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		$proc->{in}->{prof_id} = $prof_id;
		my $u = {
			prof_id => $prof_id,
			prof_pass => $in->{prof_pass_new1}
		};
		my $prof = $oprof->mod($u);
		$proc->{in} = $prof;
		#
		$self->{session}->{data}->{prof} = $prof;
		$self->{session}->update({prof=>$prof});
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $in_names, $in, $prof) = @_;
	my @errs;
	for my $k (@{$in_names}) {
		my $v = $in->{$k};
		my $len = length $v;
		#現在のパスワード
		if($k eq "prof_pass") {
			my $caption = "現在のパスワード";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} else {
				#パスワードを照合
				unless(FCC::Class::PasswdHash->new()->validate($v, $prof->{prof_pass})) {
					push(@errs, ["prof_pass", "\"${caption}\"が違います。"]);
				}
			}
		#新しいパスワード
		} elsif($k eq "prof_pass_new1") {
			my $caption = "新しいパスワード";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v eq $in->{prof_pass}) {
				push(@errs, ["prof_pass_new1", "\"${caption}\"が現在のパスワードと同じです。"]);
			}
		#新しいパスワード再入力
		} elsif($k eq "prof_pass_new2") {
			my $caption = "新しいパスワード再入力";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v ne $in->{prof_pass_new1}) {
				push(@errs, ["prof_pass_new2", "\"${caption}\"が違います。"]);
			}
		}
	}
	#
	return @errs;
}

1;
