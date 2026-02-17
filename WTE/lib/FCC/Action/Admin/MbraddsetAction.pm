package FCC::Action::Admin::MbraddsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Member;
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "mbradd");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'member_company',
		'member_dept',
		'member_title',
		'member_lastname',
		'member_firstname',
		'member_handle',
		'member_email',
		'member_pass',
		'member_skype_id',
		'member_logo',
		'member_zip1',
		'member_zip2',
		'member_addr1',
		'member_addr2',
		'member_addr3',
		'member_addr4',
		'member_tel1',
		'member_tel2',
		'member_tel3',
		'member_hp',
		'member_birthy',
		'member_birthm',
		'member_birthd',
		'member_gender',
		'member_purpose',
		'member_demand',
		'member_interest',
		'member_level',
		'member_associate1',
		'member_associate2',
		'member_intro',
		'member_comment',
		'member_status',
		'member_memo',
		'member_memo2',
		'member_logo_up',
		'member_logo_del',
		'member_lang'
	];
	#入力値を取得
	my @multiple_item_list = ('member_purpose', 'member_demand', 'member_interest', 'member_level');
	my $in = $self->get_input_data($in_names, \@multiple_item_list);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	for my $k (@multiple_item_list) {
		my @bit_list = split(//, '0' x 32);
		for my $idx (@{$proc->{in}->{$k}}) {
			$idx += 0;
			if($idx > 0 && $idx <= 32) {
				$bit_list[-$idx] = 1;
			}
		}
		my $bits = join('', @bit_list);
		$proc->{in}->{$k} = unpack("N", pack("B32", $bits));
	}
	# FCC:Class::Memberインスタンス
	my $omember = new FCC::Class::Member(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値チェック
	my @errs = $omember->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		my $member = $omember->add($proc->{in});
		$proc->{member} = $member;
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
