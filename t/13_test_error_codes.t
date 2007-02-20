#
#   $Id: 13_test_error_codes.t,v 1.3 2007/02/20 14:13:35 erwan Exp $
#
#   test Math::Polynom->solve
#

use strict;
use warnings;
use Test::More tests => 7;
use lib "../lib/";
use Math::Polynom;

is(Math::Polynom::NO_ERROR,             0, "check NO_ERROR");
is(Math::Polynom::ERROR_NAN,            1, "check ERROR_NAN");
is(Math::Polynom::ERROR_MAX_DEPTH,      2, "check ERROR_MAX_DEPTH");
is(Math::Polynom::ERROR_EMPTY_POLYNOM,  3, "check ERROR_EMPTY_POLYNOM");
is(Math::Polynom::ERROR_DIVIDE_BY_ZERO, 4, "check ERROR_DIVIDE_BY_ZERO");
is(Math::Polynom::ERROR_WRONG_SIGNS,    5, "check ERROR_WRONG_SIGNS");
is(Math::Polynom::ERROR_NOT_A_ROOT,     6, "check ERROR_NOT_A_ROOT");
