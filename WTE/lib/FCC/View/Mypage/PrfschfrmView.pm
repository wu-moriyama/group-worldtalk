package FCC::View::Mypage::PrfschfrmView;
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
	my $prof_intro_chars = $self->{tmpl_loop_params}->{row_loop}->{PROF_INTRO_CHARS} + 0;
	unless($prof_intro_chars) { $prof_intro_chars = 100; }
	my $cols = $self->{tmpl_loop_params}->{row_loop}->{COLS} + 0;
	unless($cols) { $cols = 4; }
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
	$t->param("available" => $context->{available});
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
		$hash->{"available"} = $context->{available};
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
	#検索結果の一覧
	my $res = $context->{res};
	my $row_loop = [];
	my $epoch = time;
	for(my $i=0; $i<@{$res->{list}}; $i+=$cols) {
		my $row_hash = {
			'thead_loop' => [],
			'tbody_row_loop' => []
		};
		my $prof_list = [];
		for(my $j=$i; $j<$i+$cols; $j++) {
			my $ref = $res->{list}->[$j];
			unless($ref) {
				$ref = {};
				for(my $s=1; $s<=3; $s++ ) {
					$ref->{"prof_logo_${s}_w"} = $self->{conf}->{"prof_logo_${s}_w"};
					$ref->{"prof_logo_${s}_h"} = $self->{conf}->{"prof_logo_${s}_h"};
				}
			}
			push(@{$prof_list}, $ref);
			my $th_hash = {};
			while( my($k, $v) = each %{$ref} ) {
				$th_hash->{$k} = CGI::Utils->new()->escapeHtml($v);
				if($k =~ /^(prof_cdate|prof_mdate)$/) {
					my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
					for( my $i=0; $i<=9; $i++ ) {
						$th_hash->{"${k}_${i}"} = $tm[$i];
					}
				} elsif($k eq "prof_gender") {
					$th_hash->{"${k}_${v}"} = 1;
				} elsif($k eq "prof_rank") {
					my $title = $self->{conf}->{"${k}${v}_title"};
					$th_hash->{"${k}_title"} = CGI::Utils->new()->escapeHtml($title);
				} elsif($k eq "prof_fee") {
					$th_hash->{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
				} elsif($k eq "prof_intro") {
					my $s = $v;
					$s =~ s/\x0D\x0A|\x0D|\x0A//g;
					$s =~ s/\s+/ /g;
					$s =~ s/^\s+//;
					$s =~ s/\s+$//;
					my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $prof_intro_chars);
					if($s ne $s2) { $s2 .= "…"; }
					$th_hash->{$k} = CGI::Utils->new()->escapeHtml($s2);
				} elsif($k =~ /^prof_(character|interest)$/) {
					my $bin = unpack("B32", pack("N", $v));
					my @bits = split(//, $bin);
					my @loop;
					for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
						my $title = $self->{conf}->{"${k}${id}_title"};
						my $checked = "";
						if($title eq "") { next; }
						unless( $bits[-$id] ) { next; }
						my $h = {
							id => $id,
							title => CGI::Utils->new()->escapeHtml($title)
						};
						push(@loop, $h);
					}
					$th_hash->{"${k}_loop"} = \@loop;
				}
			}
			$th_hash->{CGI_URL} = $self->{conf}->{CGI_URL};
			$th_hash->{static_url} = $self->{conf}->{static_url};
			$th_hash->{epoch} = $epoch;
			push(@{$row_hash->{'thead_loop'}}, $th_hash);
		}
		#
		for my $tm (@{$context->{time_list}}) {
			my $td_hash = {};
			$td_hash->{"h"} = $tm->{"G"};
			$td_hash->{"m"} = $tm->{"i"};
			my $tbody_col_loop = [];
			my $hm = $tm->{"H"} . $tm->{"i"};
			for my $prof (@{$prof_list}) {
				my $prof_id = $prof->{prof_id};
				my $sch_hash = $context->{sch_time_hash}->{$hm};
				if($sch_hash && $sch_hash->{$prof_id}) {
					push(@{$tbody_col_loop}, $sch_hash->{$prof_id});
				} else {
					push(@{$tbody_col_loop}, {});
				}
			}
			$td_hash->{"tbody_col_loop"} = $tbody_col_loop;
			push(@{$row_hash->{"tbody_row_loop"}}, $td_hash);
		}
		#
		push(@{$row_loop}, $row_hash);
	}
	$t->param("row_loop" => $row_loop);
	#ページナビゲーション
	my @navi_params = ('hit', 'fetch', 'start', 'end', 'next_num', 'prev_num');
	for my $k (@navi_params) {
		my $v = $res->{$k};
		$t->param($k => $v);
		$t->param("${k}_with_comma" => FCC::Class::String::Conv->new($v)->comma_format());
	}
	$t->param("next_url" => $res->{next_url});
	$t->param("prev_url" => $res->{prev_url});
	#ページナビゲーション
	$t->param("page_loop" => $res->{page_list});
	#検索条件
	while( my($k, $v) = each %{$res->{params}} ) {
		if($k =~ /^prof_(id||handle|email|fee|fulltext|reco)$/) {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
		} elsif($k =~ /^prof_(status|gender)$/) {
			$t->param("s_${k}_${v}_selected" => 'selected="selected"');
			$t->param("s_${k}_${v}" => 1);
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
			if($v ne "") {
				$t->param("s_${k}_selected" => 1);
			}
		} elsif($k =~ /^prof_(country|residence)$/) {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
			my $name = $context->{country_hash}->{$v};
			$t->param("s_${k}_name" => CGI::Utils->new()->escapeHtml($name));
		} elsif($k eq "prof_rank") {
			$t->param("s_${k}" => CGI::Utils->new()->escapeHtml($v));
			my $title = $self->{conf}->{"${k}${v}_title"};
			$t->param("s_${k}_title" => CGI::Utils->new()->escapeHtml($title));
		} elsif($k =~ /^prof_(character|interest)$/) {
			if($v && ref($v) eq "ARRAY" && @{$v} > 0) {
				my $num = 0;
				my @loop;
				for my $e (@{$v}) {
					my $title = $self->{conf}->{"${k}${e}_title"};
					$title = CGI::Utils->new()->escapeHtml($title);
					push(@loop, { title => $title });
					$num ++;
				}
				$t->param("s_${k}_target_num" => $num);
				if($num) {
					$t->param("s_${k}_target_loop" => \@loop);
				}
			}
		} elsif($k eq "sort_key") {
			$t->param($k => $v);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		} elsif($k =~ /^(limit)$/) {
			$t->param($k => $v);
			$t->param("${k}_${v}_selected" => 'selected="selected"');
		}
	}
	#検索条件の出身国/居住国
	for my $k ('prof_country', 'prof_residence') {
		my @loop;
		for my $country (@{$context->{country_list}}) {
			my $country_code = $country->[0];
			my $country_name = $country->[1];
			my $selected = "";
			if($country_code eq $res->{params}->{$k}) {
				$selected = 'selected="selected"';
			}
			my $h = {
				country_code => $country_code,
				country_name => CGI::Utils->new()->escapeHtml($country_name),
				selected => $selected
			};
			push(@loop, $h);
		}
		$t->param("s_${k}_loop" => \@loop);
	}
	#検索条件の特性/興味
	for my $k ('prof_character', 'prof_interest') {
		my @loop;
		for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
			my $title = $self->{conf}->{"${k}${id}_title"};
			my $checked = "";
			if($title eq "") { next; }
			if( grep(/^${id}$/, @{$res->{params}->{$k}}) ) {
				$checked = 'checked="checked"';
			}
			my $h = {
				id => $id,
				title => CGI::Utils->new()->escapeHtml($title),
				checked => $checked
			};
			push(@loop, $h);
		}
		$t->param("s_${k}_loop" => \@loop);
	}
	#検索条件のランク
	for my $k ('prof_rank') {
		my $v = $res->{params}->{$k} + 0;
		my @loop;
		for( my $id=1; $id<=$self->{conf}->{"${k}_num"}; $id++ ) {
			my $title = $self->{conf}->{"${k}${id}_title"};
			my $selected = "";
			if($title eq "") { next; }
			if( $id == $v ) {
				$selected = 'selected="selected"';
			}
			my $h = {
				id => $id,
				title => CGI::Utils->new()->escapeHtml($title),
				selected => $selected
			};
			push(@loop, $h);
		}
		$t->param("s_${k}_loop" => \@loop);
	}
	#
	$t->param("search_base_url" => $context->{search_base_url});
	#
	$self->print_html($t);
}

1;
