#
#   $Id: 01_test_compile.t,v 1.2 2006/12/14 10:01:09 erwan Exp $
#
#   test that Math::Polynom compiles
#

use strict;
use warnings;
use Test::More tests => 1;
use lib "../lib/";

use_ok('Math::Polynom');
