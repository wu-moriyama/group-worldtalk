package FCC::Action::Admin::MpglstfrmAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Mypg;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#インスタンス
	my $omypg = new FCC::Class::Mypg(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	#全タイトルを取得
	my $titles = $omypg->get_titles();
	#リスト生成
	my $list = [];
	for( my $id=1; $id<=20; $id++ ) {
		my $title = $titles->{$id};
		if( ! $title ) {
			$title = "";
		}
		my $ref = {
			mypg_id => $id,
			mypg_title => $title
		};
		push(@{$list}, $ref);
	}
	#
	$context->{list} = $list;
	return $context;
}


1;
