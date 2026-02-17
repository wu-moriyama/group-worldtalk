package FCC::Action::Admin::NtemodsetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::String::Checker;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "ntemod");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#入力値のname属性値のリスト
	my $in_names = [
		'note'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	while( my($k, $v) = each %{$in} ) {
		$proc->{in}->{$k} = $v;
	}
	#入力値チェック
	my @errs;
	my $len = FCC::Class::String::Checker->new($proc->{in}->{note}, "utf8")->get_char_num();
	if($len > 1000) {
		push(@errs, ["note", "1000文字以内で入力してください。"]);
	}
	#エラーハンドリング
	if(@errs) {
		$proc->{errs} = \@errs;
	} else {
		$proc->{errs} = [];
		$self->set_note($proc->{in}->{note});
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

sub set_note {
	my($self, $note) = @_;
	my $base_dir = $self->{conf}->{BASE_DIR};
	my $fcc_selector = $self->{conf}->{FCC_SELECTOR};
	my $notef = "${base_dir}/data/${fcc_selector}.note.cgi";
	open my $fh, ">", $notef;
	print $fh $note;
	close($fh);
}

1;
