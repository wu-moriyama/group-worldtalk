package FCC::Action::Admin::CpnchgsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Cpnact;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "cpnchg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'member_id',
		'cpnact_type',
		'cpnact_price'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	#入力値チェック
	my @errs = $self->input_check($in);
	#
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		#会員情報を取得
		my $ocpnact = new FCC::Class::Cpnact(conf=>$self->{conf}, db=>$self->{db});
		my $member = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_from_db($in->{member_id});
		if($member) {
			while( my($k, $v) = each %{$member} ) {
				$in->{$k} = $v;
			}
		} else {
			push(@errs, ["member_id", "「会員識別ID」に指定されたIDは存在しません。"]);
		}
		if($in->{cpnact_type} == 2 && $in->{cpnact_price} > $member->{member_coupon}) {
			push(@errs, ["cpnact_price", "指定のポイント数を減算することはできません。"]);
		}
		#
		$in->{coupon_id} = 0;
		if($in->{cpnact_type} eq "1") {
			$in->{cpnact_reason} = "12";
		} else {
			$in->{cpnact_reason} = "52";
		}
		#エラーハンドリング
		if(@errs) {
			$proc->{errs} = \@errs;
		} else {
			$proc->{errs} = [];
			my $rec = $ocpnact->charge($in);
		}
	}
	#
	$proc->{in} = $in;
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub input_check {
	my($self, $in) = @_;
	my %caps = (
		member_id => '会員識別ID',
		cpnact_type => '入出金種別',
		cpnact_price => 'ポイント'
	);
	my @errs;
	for my $k ('member_id', 'cpnact_type', 'cpnact_price') {
		my $v = $in->{$k};
		if( ! defined $v ) { $v = ""; }
		my $cap = $caps{$k};
		#会員識別ID
		if($k eq "member_id") {
			if( ! $v ) {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "「${cap}」は半角数字で指定してください。"]);
			}
		#入出金種別
		} elsif($k eq "cpnact_type") {
			if( ! $v ) {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			} elsif($v !~ /^(1|2)$/) {
				push(@errs, [$k, "「${cap}」に不正な値が送信されました。"]);
			}
		#ポイント
		} elsif($k eq "cpnact_price") {
			if( $v eq "" ) {
				push(@errs, [$k, "「${cap}」は必須です。"]);
			} elsif($v == 0) {
				push(@errs, [$k, "「${cap}」に0を指定することはできません。"]);
			} elsif($v =~ /^\-/) {
				push(@errs, [$k, "「${cap}」にマイナスを指定することはできません。"]);
			} elsif($v =~ /[^\d]/) {
				push(@errs, [$k, "「${cap}」は半角数字で指定してください。"]);
			} elsif($v > 99999999) {
				push(@errs, [$k, "「${cap}」は99999999以内で指定してください。"]);
			}
		}
	}
	return @errs;
}

1;
