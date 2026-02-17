package FCC::View::Admin::SlscntfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#テンプレートのロード
	my $t = $self->load_template();

	# 集計を置換
	for(my $i=1; $i<=9; $i++) {
		my $price = $context->{counts}->{"sum_${i}"};
		$t->param("sum_${i}" => $price);
		$t->param("sum_${i}_with_comma" => FCC::Class::String::Conv->new($price)->comma_format());
	}

	$t->param("s_sdate" => $context->{sdate});
	$t->param("s_edate" => $context->{edate});
	$self->print_html($t);
}

1;
