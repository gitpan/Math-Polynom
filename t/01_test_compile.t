#!/usr/local/bin/perl
#################################################################
#
#   $Id: 01_test_compile.t,v 1.1 2007/04/11 08:52:34 erwan_lemonnier Exp $
#
#   @author       erwan lemonnier
#   @description  test that Math::Polynom compiles
#   @system       pluto
#   @function     base
#   @function     vf
#

use strict;
use warnings;
use Test::More tests => 1;
use lib "../lib/";

use_ok('Math::Polynom');
