package FCC::Action::Admin::MbrlstajxAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Member;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = ['s_member_id', 's_member_company', 's_member_email', 's_member_status', 'limit'];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		$params->{$k} = $v;
	}
	$params->{sort} = [ ['member_id', 'DESC'] ];
	#会員情報を検索
	my $res = FCC::Class::Member->new(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd})->get_list($params);
	if($res->{hit} > $res->{params}->{limit}) {
		$res->{limit_over} = 1;
	} else {
		$res->{limit_over} = 0;
	}
	#
	$context->{res} = $res;
	return $context;
}


1;
