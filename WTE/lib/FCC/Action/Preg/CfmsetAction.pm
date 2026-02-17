package FCC::Action::Preg::CfmsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Preg::_SuperAction);
use FCC::Class::Prof;
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "preg");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		"prof_lastname",
		"prof_firstname",
		"prof_handle",
		"prof_email",
		"prof_pass",
		"prof_pass2",
		"prof_skype_id",
		"prof_zip1",
		"prof_zip2",
		"prof_addr1",
		"prof_addr2",
		"prof_addr3",
		"prof_addr4",
		"prof_tel1",
		"prof_tel2",
		"prof_tel3",
		"prof_gender",
		"prof_country",
		"prof_residence",
		"prof_character",
		"prof_interest",
		"prof_intro",
		"prof_app1",
		"prof_app2",
		"prof_app3",
		"prof_app4"
	];
	# FCC:Class::Profインスタンス
	my $oprof = new FCC::Class::Prof(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd}, pkey=>$pkey, q=>$self->{q});
	#入力値を取得
	my @multiple_item_list = ('prof_character', 'prof_interest');
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
	#入力値チェック
	my @errs = $oprof->input_check($in_names, $proc->{in});
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}


1;
