package FCC::View::Site::_SuperView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::_SuperView);
use FCC::Class::Siteparts;
use FCC::Class::Courseparts;
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;
use FCC::Class::Ann;

sub error {
	my($self, $errs) = @_;
	my @list = @{$errs};
	my $n = scalar @list;
	my $msg;
	if($n == 1) {
		$msg = $list[0];
	} else {
		$msg .= "<ul>";
		for my $s (@list) {
			$msg .= "<li>${s}</li>";
		}
		$msg .= "</ul>";
	}
	my $t = $self->load_template("$self->{conf}->{BASE_DIR}/template/$self->{conf}->{FCC_SELECTOR}/error.html");
	$t->param('error' => $msg);
	$self->print_html($t);
}

sub load_template {
	my($self, $f, $tmpl) = @_;
	my $seller_id = 0;
	if($self->{session}->{data}->{member}) {
		$seller_id = $self->{session}->{data}->{member}->{seller_id};
	}
	if( ! $f && ! $tmpl) {
		if($self =~ /^FCC::View::([\w\:]+)/) {
			my $v = $1;
			$v =~ s/\:\:/\//g;
			$v =~ s/View$//;
			if($v =~ /\/Default$/) {
				my $m = $self->{q}->param('m');
				if($m) {
					if($m =~ /[^a-zA-Z0-9]/) {
						$self->error404();
					} else {
						$m = ucfirst $m;
						$v =~ s/\/Default$/\/${m}/;
					}
				} else {
					$v =~ s/\/Default$/\/Index/;
				}
			}
			$f = "$self->{conf}->{BASE_DIR}/template/${v}.html";
			if($seller_id) {
				my $f2 = $f;
				$f2 =~ s/\/([a-zA-Z0-9]+\.html)$/\/${seller_id}\/$1/;
				if(-e $f2) {
					$f = $f2;
				}
			}
		} else {
			$self->error404();
		}
	}
	#テンプレートファイルをロード
	if( ! $tmpl ) {
		unless( -e $f ) {
			$self->error404();
		}
		$tmpl = File::Read::read_file($f);
	}
	#HTML::Templateオブジェクトを生成
	my $params = {};
	my $filter = sub {
		my $text_ref = shift;
		my $regexpfilter = sub {
			my($name,$paramstr) = @_;
			my @ary = split(/\s+/, $paramstr);
			for my $pair (@ary) {
				if( my($k, $v) = $pair =~ /^([A-Z\_]+)\=\"([\d\,]+)\"/ ) {
					$params->{$name}->{$k} = $v;
				}
			}
			return "<TMPL_LOOP NAME=\"${name}\">";
		};
		$$text_ref =~ s/<TMPL_LOOP\s+NAME=\"([^\s\t]+)\"\s+([^\>\<]+)>/&{$regexpfilter}($1,$2)/eg;
	};
	my $tmpl_path = "$self->{conf}->{BASE_DIR}/template/$self->{conf}->{FCC_SELECTOR}";
	my $tmpl_path_list = [$tmpl_path];
	if($seller_id) {
		unshift @{$tmpl_path_list}, "${tmpl_path}/${seller_id}";
	}
	my $t = HTML::Template->new(
		scalarref => \$tmpl,
		die_on_bad_params => 0,
		vanguard_compatibility_mode => 1,
		loop_context_vars => 1,
		filter => $filter,
		path => $tmpl_path_list,
		case_sensitive => 1
	);
	#
	$self->{tmpl_loop_params} = $params;
	my @parameter_names = $t->param();
	#
	unless($self->{q}) {
		$self->{q} = new CGI;
	}
	#
	while( my($k, $v) = each %{$self->{conf}} ) {
		$t->param($k => CGI::Utils->new()->escapeHtml($v));
	}
	#
	if($self->{session}->{data}) {
		while( my($k, $v) = each %{$self->{session}->{data}} ) {
			if($k =~ /^seller_inc\d+$/) {
				$t->param("session_${k}" => $v);
			} else {
				$t->param("session_${k}" => CGI::Utils->new()->escapeHtml($v));
			}
		}
	}
	
	#各種パーツ
	my $osp = new FCC::Class::Siteparts(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	if( grep(/^pref_new_loop$/, @parameter_names) ) {
		my $prof_intro_chars = $params->{pref_new_loop}->{PROF_INTRO_CHARS} + 0;
		unless($prof_intro_chars) { $prof_intro_chars = 100; }
		my $limit = $params->{pref_new_loop}->{LIMIT} + 0;
		unless($limit) { $limit = 5; }
		#
		my $list = $osp->get_prof_new();
		my @loop;
		my $n = 0;
		for my $ref (@{$list}) {
			my $hash = $self->make_prof_list_template_hash($ref, $prof_intro_chars);
			push(@loop, $hash);
			$n ++;
			if($n >= $limit) { last; }
		}
		$t->param("pref_new_loop" => \@loop);
	}
	if( grep(/^pref_score_loop$/, @parameter_names) ) {
		my $prof_intro_chars = $params->{pref_score_loop}->{PROF_INTRO_CHARS} + 0;
		unless($prof_intro_chars) { $prof_intro_chars = 100; }
		my $limit = $params->{pref_score_loop}->{LIMIT} + 0;
		unless($limit) { $limit = 5; }
		#
		my $list = $osp->get_prof_score();
		my @loop;
		my $n = 0;
		for my $ref (@{$list}) {
			my $hash = $self->make_prof_list_template_hash($ref, $prof_intro_chars);
			push(@loop, $hash);
			$n ++;
			if($n >= $limit) { last; }
		}
		$t->param("pref_score_loop" => \@loop);
	}


	my $ocp = new FCC::Class::Courseparts(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
	if( grep(/^pref_cscore_loop$/, @parameter_names) ) {
		my $course_intro_chars = $params->{pref_cscore_loop}->{COURSE_INTRO_CHARS} + 0;
		unless($course_intro_chars) { $course_intro_chars = 300; }
		my $limit = $params->{pref_cscore_loop}->{LIMIT} + 0;
		unless($limit) { $limit = 5; }
		#
		my $list = $ocp->get_course_score();
		my @loop;
		my $n = 0;
		for my $ref (@{$list}) {
			my $hash = $self->make_course_list_template_hash($ref, $course_intro_chars);
			push(@loop, $hash);
			$n ++;
			if($n >= $limit) { last; }
		}
		$t->param("pref_cscore_loop" => \@loop);
	}
	if( grep(/^pref_cscore2_loop$/, @parameter_names) ) {
		my $course_intro_chars = $params->{pref_cscore2_loop}->{COURSE_INTRO_CHARS} + 0;
		unless($course_intro_chars) { $course_intro_chars = 300; }
		my $limit = $params->{pref_cscore2_loop}->{LIMIT} + 0;
		unless($limit) { $limit = 5; }
		#
		my $list = $ocp->get_course_score2();
		my @loop;
		my $n = 0;
		for my $ref (@{$list}) {
			my $hash = $self->make_course_list_template_hash($ref, $course_intro_chars);
			push(@loop, $hash);
			$n ++;
			if($n >= $limit) { last; }
		}
		$t->param("pref_cscore2_loop" => \@loop);
	}
	if( grep(/^pref_cscore3_loop$/, @parameter_names) ) {
		my $course_intro_chars = $params->{pref_cscore3_loop}->{COURSE_INTRO_CHARS} + 0;
		unless($course_intro_chars) { $course_intro_chars = 300; }
		my $limit = $params->{pref_cscore3_loop}->{LIMIT} + 0;
		unless($limit) { $limit = 5; }
		#
		my $list = $ocp->get_course_score3();
		my @loop;
		my $n = 0;
		for my $ref (@{$list}) {
			my $hash = $self->make_course_list_template_hash($ref, $course_intro_chars);
			push(@loop, $hash);
			$n ++;
			if($n >= $limit) { last; }
		}
		$t->param("pref_cscore3_loop" => \@loop);
	}


	#お知らせ
	if( grep(/^ann_loop$/, @parameter_names) ) {
		my $oann = new FCC::Class::Ann(conf=>$self->{conf}, db=>$self->{db}, memd=>$self->{memd});
		my $ann_list = $oann->get_list_for_dashboard(4);
		my @ann_loop;
		for my $ann (@{$ann_list}) {
			my %h;
			while( my($k, $v) = each %{$ann} ) {
				$h{$k} = CGI::Utils->new()->escapeHtml($v);
				if($k eq "ann_cdate") {
					my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
					for( my $i=0; $i<=9; $i++ ) {
						$h{"${k}_${i}"} = $tm[$i];
					}
				} elsif($k eq "ann_content") {
					$v = CGI::Utils->new()->escapeHtml($v);
					$v =~ s/(https?\:\/\/[0-9a-zA-Z\:\/\.\-\_\#\%\&\=\~\+\?\;\,]+)/<a href=\"$1\" target=\"_blank\">$1<\/a\>/g;
					$v =~ s/\n/<br \/>/g;
					$h{$k} = $v;
				}
			}
			push(@ann_loop, \%h);
		}
		$t->param("ann_loop" => \@ann_loop);
	}
	#
	return $t;
}

sub make_prof_list_template_hash {
	my($self, $ref, $prof_intro_chars) = @_;
	my $epoch = time;
	my %hash;
	while( my($k, $v) = each %{$ref} ) {
		$hash{$k} = CGI::Utils->new()->escapeHtml($v);
		if($k =~ /^(prof_cdate|prof_mdate)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$hash{"${k}_${i}"} = $tm[$i];
			}
		} elsif($k eq "prof_gender") {
			$hash{"${k}_${v}"} = 1;
		} elsif($k eq "prof_rank") {
			my $title = $self->{conf}->{"${k}${v}_title"};
			$hash{"${k}_title"} = CGI::Utils->new()->escapeHtml($title);
		} elsif($k eq "prof_fee") {
			$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
		} elsif($k eq "prof_intro") {
			my $s = $v;
			$s =~ s/\x0D\x0A|\x0D|\x0A//g;
			$s =~ s/\s+/ /g;
			$s =~ s/^\s+//;
			$s =~ s/\s+$//;
			my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $prof_intro_chars);
			if($s ne $s2) { $s2 .= "…"; }
			$hash{$k} = CGI::Utils->new()->escapeHtml($s2);
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
			$hash{"${k}_loop"} = \@loop;
		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
	}
	return \%hash;
}

sub make_course_list_template_hash {
	my($self, $ref, $course_intro_chars) = @_;
	my $epoch = time;
	my %hash;
	while( my($k, $v) = each %{$ref} ) {
		$hash{$k} = CGI::Utils->new()->escapeHtml($v);
		if($k =~ /^(course_cdate|course_mdate)$/) {
			my @tm = FCC::Class::Date::Utils->new(time=>$v, tz=>$self->{conf}->{tz})->get(1);
			for( my $i=0; $i<=9; $i++ ) {
				$hash{"${k}_${i}"} = $tm[$i];
			}
		} elsif($k eq "course_fee") {
			$hash{"${k}_with_comma"} = FCC::Class::String::Conv->new($v)->comma_format();
		} elsif($k eq "course_intro") {
			#my $s = $v;
			#$s =~ s/\x0D\x0A|\x0D|\x0A//g;
			#$s =~ s/\s+/ /g;
			#$s =~ s/^\s+//;
			#$s =~ s/\s+$//;
			#my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $course_intro_chars);
			#if($s ne $s2) { $s2 .= "…"; }
			#$hash{$k} = CGI::Utils->new()->escapeHtml($s2);

			# HTMLタグ除去
			my $s = $v;
			$s =~ s/<[^>]+>//g;

			# &nbsp; → スペース
			$s =~ s/&nbsp;/ /g;

			# 余計な空白を整形
			$s =~ s/\x0D\x0A|\x0D|\x0A/\n/g;   # 改行統一
			$s =~ s/\s+/ /g;                   # 連続空白を1つに
			$s =~ s/^\s+//;
			$s =~ s/\s+$//;

			# 文字数制限（LP 上の見た目を整える）
			my $s2 = FCC::Class::String::Conv->new($s)->truncate_chars(0, $course_intro_chars);
			if($s ne $s2) { $s2 .= "…"; }

			# 最後に escapeHtml
			$s2 = CGI::Utils->new()->escapeHtml($s2);

			$hash{$k} = $s2;

		}
		$hash{CGI_URL} = $self->{conf}->{CGI_URL};
		$hash{static_url} = $self->{conf}->{static_url};
		$hash{epoch} = $epoch;
	}
	return \%hash;
}

1;
