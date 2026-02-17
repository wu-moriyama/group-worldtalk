package FCC::Action::Admin::PntcnttsvdwnAction;
$VERSION = 1.00;
use strict;
use warnings;
use base qw(FCC::Action::Admin::_SuperAction);
use Date::Pcalc;
use Unicode::Japanese;
use FCC::Class::Salescount;

sub dispatch {
    my ($self) = @_;
    my $context = {};

    my $fname = $self->{q}->param("fname");
    if(!$fname || $fname !~ /^\d{12}\.csv$/) {
        $context->{fatalerrs} = ["ファイル名が不正です。"];
        return $context;
    }

    my $dir = $self->{conf}->{BASE_DIR} . "/data/pointcount";
    my $fpath = $dir . "/" . $fname;
    unless(-e $fpath) {
        $context->{fatalerrs} = ["指定のファイルが見つかりませんでした。"];
        return $context;
    }

    my $fh;
    unless(open $fh, '<', $fpath) {
        $context->{fatalerrs} = ["指定のファイルを開くことができませんでした: " . $!];
        return $context;
    }

    my $csv;
    my $size = -s $fpath;
    read $fh, $csv, $size;
    close $fh;

    $csv = Unicode::Japanese->new($csv, "utf8")->conv("sjis");

    $context->{csv} = $csv;
    $context->{length} = length $csv;
    $context->{fname} = $fname;
    return $context;
}

1;
