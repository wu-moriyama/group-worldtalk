package FCC::View::Mypage::LsnrsvfavfrmView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Mypage::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;

sub dispatch {
	my($self, $context) = @_;
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		return;
	}
	my $t = $self->load_template();
	#
	$t->param("ymd" => $context->{ymd});
	my($Y, $M, $D) = $context->{ymd} =~ /^(\d{4})(\d{2})(\d{2})/;
	my $dt_epoch = FCC::Class::Date::Utils->new(iso=>"${Y}-${M}-${D} 12:00:00", tz=>$self->{conf}->{tz})->epoch();
	my %fmt = FCC::Class::Date::Utils->new(time=>$dt_epoch, tz=>$self->{conf}->{tz})->get_formated();
	while( my($k, $v) = each %fmt ) {
		$t->param("dt_${k}" => $v);
	}
	my @week_map = ("日", "月", "火", "水", "木", "金", "土");
	$t->param("dt_wj" => $week_map[$fmt{w}]);
	#
	my $loops = {};
	my $epoch = time;
	for my $sch (@{$context->{sch_list}}) {
		my($Y, $M, $D, $h, $m) = $sch->{sch_stime} =~ /^(\d{4})\-(\d{2})\-(\d{2})\s+(\d{2})\:(\d{2})/;
		my $hour = $h + 0;
		my $loop_name = "sch_loop_" . ( int($hour / 4) + 1 );
		unless($loops->{$loop_name}) { $loops->{$loop_name} = []; }
		my $hash = {};
		while( my($k, $v) = each %{$sch} ) {
			$hash->{$k} = CGI::Utils->new()->escapeHtml($v);
			if($k =~ /^(prof_cdate|prof_mdate)$/) {
				my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
				for( my $i=0; $i<=9; $i++ ) {
					$hash->{"${k}_${i}"} = $tm[$i];
				}
			} elsif($k =~ /^prof_(gender|status|card|reco|coupon_ok)$/) {
				$hash->{"${k}_${v}"} = 1;
			} elsif($k =~ /^prof_(associate1|associate2|intro|intro2|memo|memo2|note)$/) {
				my $tmp = CGI::Utils->new()->escapeHtml($v);
				$tmp =~ s/\n/<br \/>/g;
				$hash->{$k} = $tmp;
			} elsif($k eq "prof_rank") {
				my $title = $self->{conf}->{"prof_rank${v}_title"};
				$hash->{"${k}_title"} = CGI::Utils->new()->escapeHtml($title);
			} elsif($k eq "prof_fee") {
				$hash->{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
			}
		}
		$hash->{static_url} = $self->{conf}->{static_url};
		$hash->{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash->{epoch} = $epoch;
		push(@{$loops->{$loop_name}}, $hash);
	}
	while( my($k, $v) = each %{$loops} ) {
		$t->param($k => $v);
	}
	#
	my @week_loop;
	for my $ymd (@{$context->{week}}) {
		my($Y, $M, $D) = $ymd =~ /^(\d{4})(\d{2})(\d{2})/;
		my $dt_epoch = FCC::Class::Date::Utils->new(iso=>"${Y}-${M}-${D} 12:00:00", tz=>$self->{conf}->{tz})->epoch();
		my %fmt = FCC::Class::Date::Utils->new(time=>$dt_epoch, tz=>$self->{conf}->{tz})->get_formated();
		my $hash = {};
		while( my($k, $v) = each %fmt ) {
			$hash->{"dt_${k}"} = $v;
		}
		$hash->{"dt_wj"} = $week_map[$fmt{w}];
		if($ymd eq $context->{ymd}) {
			$hash->{current} = 1;
		} else {
			$hash->{current} = 0;
		}
		$hash->{CGI_URL} = $self->{conf}->{CGI_URL};
		push(@week_loop, $hash);
	}
	$t->param("week_loop" => \@week_loop);
	#
	$self->print_html($t);
}

1;
