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
use FCC::Controller;
#$| = 1;

{
	my $params = {};
	$params->{BASE_DIR} = '/var/www/WTE';
	$params->{FCC_SELECTOR} = 'Admin';
	my $c = new FCC::Controller(params=>$params);
	$c->dispatch();
}
exit;

