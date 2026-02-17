package FCC::View::Admin::SdmlsndwnView;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::View::Admin::_SuperView);
use CGI::Utils;
use FCC::Class::Date::Utils;
use FCC::Class::String::Conv;
use Unicode::Japanese;

sub dispatch {
	my($self, $context) = @_;
	#システムエラーの評価
	if($context->{fatalerrs}) {
		$self->error($context->{fatalerrs});
		exit;
	}
	#レッスン内訳
	my $head_cols = [
		"レッスン識別ID",
		"$self->{conf}->{prof_caption}識別ID",
		"姓",
		"名",
		"ニックネーム",
		"$self->{conf}->{member_caption}識別ID",
		"姓",
		"名",
		"ニックネーム",
		"日時",
		"$self->{conf}->{prof_caption}配分"
	];
	my $head_line = $self->make_csv_line($head_cols);
	my $csv = Unicode::Japanese->new($head_line, "utf8")->conv("sjis") . "\n";
	for my $ref (@{$context->{lsn_list}}) {
		my $cols = [
			$ref->{lsn_id},
			$ref->{prof_id},
			$ref->{prof_lastname},
			$ref->{prof_firstname},
			$ref->{prof_handle},
			$ref->{member_id},
			$ref->{member_lastname},
			$ref->{member_firstname},
			$ref->{member_handle},
			"$ref->{lsn_stime_Y}年$ref->{lsn_stime_n}月$ref->{lsn_stime_j}日（$ref->{lsn_stime_wj}）$ref->{lsn_stime_G}:$ref->{lsn_stime_i}～$ref->{lsn_etime_G}:$ref->{lsn_etime_i}",
			$ref->{lsn_seller_price}
		];
		my $line = $self->make_csv_line($cols) . "\n";
		$line =~ s/(\x0d|\x0a)//g;
		$line = Unicode::Japanese->new($line, "utf8")->conv("sjis");
		$csv .= $line . "\n";
	}
	#CSVのファイル名
	my @tm = FCC::Class::Date::Utils->new(time=>time, tz=>$self->{conf}->{tz})->get(1);
	my $filename = "sdm." . $context->{sdm}->{sdm_id} . ".$tm[0]$tm[1]$tm[2]$tm[3]$tm[4]$tm[5].csv";
	#
	my $length = length $csv;
	print "Content-Type: application/octet-stream\n";
	print "Content-Disposition: attachment; filename=${filename}\n";
	print "Content-Length: ${length}\n";
	print "\n";
	print $csv;
}

sub make_csv_line {
	my($self, $ary) = @_;
	my @cols;
	for my $elm (@{$ary}) {
		my $v = $elm;
		$v =~ s/\"/\"\"/g;
		$v = '"' . $v . '"';
		push(@cols, $v);
	}
	my $line = join(",", @cols);
	return $line;
}

1;
