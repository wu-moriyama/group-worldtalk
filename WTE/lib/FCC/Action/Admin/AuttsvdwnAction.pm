package FCC::Action::Admin::AuttsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Auto;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = [
		's_auto_id',
		's_member_id',
		's_auto_status',
		's_auto_stop_reason'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		$params->{$k} = $v;
	}
	$params->{sort} = [ ['auto_id', 'DESC'] ];
	$params->{charcode} = "sjis";
	$params->{returncode} = "\x0a";
	#CSVを生成
	my $oauto = new FCC::Class::Auto(conf=>$self->{conf}, db=>$self->{db});
	my $res = $oauto->get_csv($params);
	#
	$context->{res} = $res;
	return $context;
}


1;
