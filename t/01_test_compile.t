#
#   $Id: 01_test_compile.t,v 1.1.1.1 2006/10/25 02:24:09 erwan Exp $
#
#   test that Math::Polynom compiles
#

use strict;
use warnings;
use Test::More tests => 1;
use lib "../lib/";

use_ok('Math::Polynom');
