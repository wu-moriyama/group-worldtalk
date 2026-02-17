package FCC::Action::Admin::DctlstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Dct;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#プロセスセッション
	my $proc = $self->create_proc_session_data("dctlst");
	#インスタンス
	my $odct = new FCC::Class::Dct(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#全カテゴリー情報を取得
	my $dcts = $odct->get_from_db();
	#リストとして並べ替え
	my $list = [];
	for my $id ( sort { $dcts->{$a}->{dct_sort} <=> $dcts->{$b}->{dct_sort} } keys %{$dcts} ) {
		push(@{$list}, $dcts->{$id});
	}
	#
	$context->{proc} = $proc;
	$context->{list} = $list;
	return $context;
}


1;
