#!/usr/bin/perl
######################################################################
# FCCフレームワーク
# Copyright(C) futomi 2010
# http://www.futomi.com/
######################################################################
BEGIN {
	push(@INC, "/var/www/WTE/lib");
}
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser);
use FCC::ControllerProf;
#$| = 1;

{
	my $params = {};
	$params->{BASE_DIR} = '/var/www/WTE';
	$params->{FCC_SELECTOR} = 'Prof';
	my $c = new FCC::ControllerProf(params=>$params);
	$c->dispatch();
}
exit;

