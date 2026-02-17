package FCC::Action::_SuperAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::_Super);
use File::Read;
use HTML::Template;

sub load_template {
	my($self, $f) = @_;
	#テンプレートファイルをロード
	my $tmpl = File::Read::read_file($f);
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
	my $t = HTML::Template->new(
		scalarref => \$tmpl,
		die_on_bad_params => 0,
		vanguard_compatibility_mode => 1,
		loop_context_vars => 1,
		filter => $filter
	);
	$t->param("mbr_mail_common_text1" => $self->{conf}->{mbr_mail_common_text1});
	$t->param("mbr_mail_common_text2" => $self->{conf}->{mbr_mail_common_text2});
	$self->{template}->{params} = $params;
	return $t;
}

sub get_input_data {
	my($self, $target_cols, $array_cols) = @_;
	my @cols;
	if($target_cols && ref($target_cols) eq "ARRAY") {
		@cols = @{$target_cols};
	} else {
		@cols = $self->{q}->param();
	}
	my %arys;
	if($array_cols && ref($array_cols) eq "ARRAY") {
		for my $col (@{$array_cols}) {
			$arys{$col} = 1;
		}
	}
	my $in = {};
	for my $col (@cols) {
		my $v;
		if($arys{$col}) {
			my @list = $self->{q}->param($col);
			$v = \@list;
		} else {
			$v = $self->{q}->param($col);
			if(defined $v) {
				if(!ref($v)) {
					$v =~ s/\x0d\x0a/\n/g;
					$v =~ s/\x0d/\n/g;
					$v =~ s/\x0a/\n/g;
				}
			} else {
				$v = "";
			}
		}
		$in->{$col} = $v;
	}
	return $in;
}

sub get_proc_session_data {
	my($self, $pkey, $pname) = @_;
	if( ! defined $pkey ) { $pkey = ""; }
	#プロセスキー
	if($pkey eq "" || $pkey !~ /^[a-zA-Z0-9]{32}$/) {
		return undef;
	}
	#プロセスデータ
	my $proc = $self->{session}->{data}->{proc};
	if( ! $proc || ! $proc->{pkey} || $proc->{pkey} ne $pkey || $proc->{pname} ne $pname ) {
		return undef;
	}
	#
	return $proc;
}

sub set_proc_session_data {
	my($self, $proc) = @_;
	$self->{session}->{data}->{proc} = $proc;
	$self->{session}->update( { proc => $proc } );
}

sub create_proc_session_data {
	my($self, $pname) = @_;
	my $pkey = $self->{session}->generate_sid();
	my $proc = {
		pkey => $pkey,
		pname => $pname,
		in => {},
		errs => []
	};
	$self->{session}->{data}->{proc} = $proc;
	$self->{session}->update( { proc => $proc } );
	return $proc;
}

sub del_proc_session_data {
	my($self) = @_;
	my $proc = $self->{session}->{data}->{proc};
	delete $self->{session}->{data}->{proc};
	$self->{session}->update( { proc => undef } );
	return $proc;
}

1;
