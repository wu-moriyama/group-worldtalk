package FCC::Action::Admin::MbractdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::Mbract;

sub dispatch {
	my($self) = @_;
	my $context = {};
	#入力値のname属性値のリスト
	my $in_names = [
		's_member_id',
		's_cdate1',
		's_cdate2'
	];
	#入力値を取得
	my $in = $self->get_input_data($in_names);
	my $params = {};
	while( my($k, $v) = each %{$in} ) {
		if( ! defined $v || $v eq "" ) { next; }
		$k =~ s/^s_//;
		if($k eq "cdate1") {
			if($v =~ /^\d{4}\-\d{2}\-\d{2}$/) {
				my $iso = "${v} 00:00:00";
				$params->{"mbract_cdate1"} = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz}, iso=>$iso)->epoch();
			} else {
				next;
			}
		} elsif($k eq "cdate2") {
			if($v =~ /^\d{4}\-\d{2}\-\d{2}$/) {
				my $iso = "${v} 23:59:59";
				$params->{"mbract_cdate2"}  = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz}, iso=>$iso)->epoch();
			} else {
				next;
			}
		}
		$params->{$k} = $v;
	}
	$params->{sort} = [ ['mbract_id', 'DESC'] ];
	$params->{charcode} = "sjis";
	$params->{returncode} = "\x0a";
	#CSVを生成
	my $ombract = new FCC::Class::Mbract(conf=>$self->{conf}, db=>$self->{db});
	my $res = $ombract->get_csv($params);
	#
	$context->{res} = $res;
	return $context;
}


1;
