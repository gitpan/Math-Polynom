#!/usr/local/bin/perl
#################################################################
#
#   $Id: 20_test__is_nan.t,v 1.1 2007/04/11 08:52:34 erwan_lemonnier Exp $
#
#   @author       erwan lemonnier
#   @description  test Math::Polynom _is_nan
#   @system       pluto
#   @function     base
#   @function     vf
#

use strict;
use warnings;
use Test::More tests => 6;
use lib "../lib/";

use_ok('Math::Polynom');

my @tests = (
	     'nan', 1,
	     'NaN', 1,
	     0, 0,
	     1233123.568972934578, 0,
	     undef, 1,
	     );

while (@tests) {
    my $scalar = shift @tests;
    my $expect = shift @tests;
    is(Math::Polynom::_is_nan($scalar),$expect,"".((defined $scalar)?"$scalar":"undef")." is ".(($expect)?"not":"")." a number");
}

