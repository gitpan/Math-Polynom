#
#   $Id: 13_test_error_codes.t,v 1.1 2006/11/06 07:34:35 erwan Exp $
#
#   test Math::Polynom->solve
#

use strict;
use warnings;
use Test::More tests => 4;
use lib "../lib/";
use Math::Polynom;

is(Math::Polynom::NO_ERROR,            0, "check NO_ERROR");
is(Math::Polynom::ERROR_NAN,           1, "check ERROR_NAN");
is(Math::Polynom::ERROR_MAX_DEPTH,     2, "check ERROR_MAX_DEPTH");
is(Math::Polynom::ERROR_EMPTY_POLYNOM, 3, "check ERROR_EMPTY_POLYNOM");
