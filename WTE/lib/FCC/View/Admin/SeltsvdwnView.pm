package FCC::View::Admin::SeltsvdwnView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#TSVのファイル名
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $filename = "seller.$tm[0]$tm[1]$tm[2]$tm[3]$tm[4]$tm[5].csv";
	#
	my $res = $context->{res};
	print "Content-Type: application/octet-stream\n";
	print "Content-Disposition: attachment; filename=${filename}\n";
	print "Content-Length: $res->{length}\n";
	print "\n";
	print $res->{csv};
}

1;
