package FCC::Action::Admin::DwntsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Dwn;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = [
		's_dwn_id',
		's_dct_id',
		's_dwn_type',
		's_dwn_loc',
		's_dwn_status',
		'sort_key'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		$params->{$k} = $v;
	}
	unless( $params->{sort_key} ) {
		$params->{sort_key} = "new";
	}
	if($params->{sort_key} eq "score") {
		$params->{sort} = [ ['dwn_weight', 'DESC'], ['dwn_score', 'DESC'], ['dwn_id', 'DESC'] ];
	} elsif($params->{sort_key} eq "new") {
		$params->{sort} = [ ['dwn_pubdate', 'DESC'], ['dwn_id', 'DESC'] ];
	} else {
		$params->{sort} = [ ['dwn_id', 'DESC'] ];
		$params->{sort_key} = 'id';
	}

	$params->{charcode} = "sjis";
	$params->{returncode} = "\x0a";
	#CSVを生成
	my $odwn = new FCC::Class::Dwn(conf=>$self->{conf}, db=>$self->{db});
	my $res = $odwn->get_csv($params);
	#
	$context->{res} = $res;
	return $context;
}


1;
