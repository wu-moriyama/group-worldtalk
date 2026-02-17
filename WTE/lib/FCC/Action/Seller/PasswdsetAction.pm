package FCC::Action::Seller::PasswdsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Seller::_SuperAction);
use FCC::Class::Seller;
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
		'seller_pass',
		'seller_pass_new1',
		'seller_pass_new2'
	];
	# FCC:Class::Sellerインスタンス
	my $oseller = new FCC::Class::Seller(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#営業会社情報を取得
	my $seller_id = $self->{session}->{data}->{seller}->{seller_id};
	my $seller = $oseller->get_from_db($seller_id);
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs = $self->input_check($in_names, $proc->{in}, $seller);
	#
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $u = {
			seller_id => $seller_id,
			seller_pass => $in->{seller_pass_new1}
		};
		my $seller = $oseller->mod($u);
		$proc->{in} = $seller;
		#
		$self->{session}->{data}->{seller} = $seller;
		$self->{session}->update({seller=>$seller});
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $in_names, $in, $seller) = @_;
	my @errs;
	for my $k (@{$in_names}) {
		my $v = $in->{$k};
		my $len = length $v;
		#現在のパスワード
		if($k eq "seller_pass") {
			my $caption = "現在のパスワード";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 255) {
				push(@errs, [$k, "\"${caption}\" は8文字以上255文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} else {
				#パスワードを照合
				unless(FCC::Class::PasswdHash->new()->validate($v, $seller->{seller_pass})) {
					push(@errs, ["seller_pass", "\"${caption}\"が違います。"]);
				}
			}
		#新しいパスワード
		} elsif($k eq "seller_pass_new1") {
			my $caption = "新しいパスワード";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 255) {
				push(@errs, [$k, "\"${caption}\" は8文字以上255文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v eq $in->{seller_pass}) {
				push(@errs, ["seller_pass_new1", "\"${caption}\"が現在のパスワードと同じです。"]);
			}
		#新しいパスワード再入力
		} elsif($k eq "seller_pass_new2") {
			my $caption = "新しいパスワード再入力";
			if($v eq "") {
				push(@errs, [$k, "\"${caption}\" は必須です。"]);
			} elsif($len < 8 || $len > 255) {
				push(@errs, [$k, "\"${caption}\" は8文字以上255文字以内で入力してください。"]);
			} elsif($v =~ /[^\x21-\x7e]/) {
				push(@errs, [$k, "\"${caption}\" に不適切な文字が含まれています。"]);
			} elsif($v ne $in->{seller_pass_new1}) {
				push(@errs, ["seller_pass_new2", "\"${caption}\"が違います。"]);
			}
		}
	}
	#
	return @errs;
}

1;
