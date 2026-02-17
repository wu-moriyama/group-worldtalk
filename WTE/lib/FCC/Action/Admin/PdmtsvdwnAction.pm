package FCC::Action::Admin::PdmtsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Pdm;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = [
		's_pdm_id',
		's_prof_id',
		's_pdm_status'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		$params->{$k} = $v;
	}
	$params->{sort} = [ ['pdm_id', 'DESC'] ];
	$params->{charcode} = "sjis";
	$params->{returncode} = "\x0a";
	#CSVを生成
	my $opdm = new FCC::Class::Pdm(conf=>$self->{conf}, db=>$self->{db});
	my $res = $opdm->get_csv($params);
	#
	$context->{res} = $res;
	return $context;
}


1;
