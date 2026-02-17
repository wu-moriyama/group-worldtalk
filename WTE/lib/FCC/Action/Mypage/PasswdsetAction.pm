package FCC::Action::Mypage::PasswdsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Mypage::_SuperAction);
use FCC::Class::Member;
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
		'member_pass',
		'member_pass_new1',
		'member_pass_new2'
	];
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#会員情報を取得
	my $member_id = $self->{session}->{data}->{member}->{member_id};
	my $member = $omember->get_from_db($member_id);
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in}, $member);
	#
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		$proc->{in}->{member_id} = $member_id;
		my $u = {
			member_id => $member_id,
			member_pass => $in->{member_pass_new1}
		};
		my $member = $omember->mod($u);
		$proc->{in} = $member;
		#
		$self->{session}->{data}->{member} = $member;
		$self->{session}->update({member=>$member});
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $in_names, $in, $member) = @_;
	my @errs;
	for my $k (@{$in_names}) {
		my $v = $in->{$k};
		my $len = length $v;
		#現在のパスワード
		if($k eq "member_pass") {
			my $caption = "現在のパスワード";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} else {
				#パスワードを照合
				unless(FCC::Class::PasswdHash->new()->validate($v, $member->{member_pass})) {
					push(@errs, ["member_pass", "\"${caption}\"が違います。"]);
				}
			}
		#新しいパスワード
		} elsif($k eq "member_pass_new1") {
			my $caption = "新しいパスワード";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v eq $in->{member_pass}) {
				push(@errs, ["member_pass_new1", "\"${caption}\"が現在のパスワードと同じです。"]);
			}
		#新しいパスワード再入力
		} elsif($k eq "member_pass_new2") {
			my $caption = "新しいパスワード再入力";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 20) {
				push(@errs, [$k, "\"${caption}\" は8文字以上20文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v ne $in->{member_pass_new1}) {
				push(@errs, ["member_pass_new2", "\"${caption}\"が違います。"]);
			}
		}
	}
	#
	return @errs;
}

1;
