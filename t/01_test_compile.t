#################################################################
#
#   $Id: 01_test_compile.t,v 1.3 2007/04/17 19:28:31 erwan_lemonnier Exp $
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
