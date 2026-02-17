package FCC::Action::Admin::DwnflesetAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use FCC::Class::Dwn;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $pkey = $self->{q}->param("pkey");
	my $proc = $self->get_proc_session_data($pkey, "dwnfle");
	if( ! $proc) {
		$context->{fatalerrs} = ["不正なリクエストです。"];
		return $context;
	}
	#
	my $dwn_id = $proc->{in}->{dwn_id};
	#ファイル名のチェック
	my $file_name = $self->{q}->param("dwn_file");
	if( ! $file_name ) {
		$proc->{errs} = [["dwn_file", "ファイルを指定してください。"]];
	} elsif( $file_name =~ /[^a-zA-Z0-9\-\_\.]/ ) {
		$proc->{errs} = [["dwn_file", "ファイル名に、半角英数字、ハイフン、アンダースコア、ドット以外の文字を指定することはできません。"]];
	} elsif( length($file_name) > 100 ) {
		$proc->{errs} = [["dwn_file", "ファイル名は100文字以内にしてください。"]];
	} else {
		# FCC:Class::Dwnインスタンス
		my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db}, pkey=>$pkey, q=>$self->{q});
		#ファイルアップロード
		my $res = $odwn->register_file($dwn_id, "dwn_file", $file_name);
		#エラーハンドリング
		if($res->{is_error}) {
			$proc->{errs} = [["dwn_file", $res->{error}]];
		} else {
			$proc->{errs} = [];
			$proc->{in}->{dwn_fpath} = $res->{path};
		}
	}
	#
	$self->set_proc_session_data($proc);
	$context->{proc} = $proc;
	return $context;
}

1;
