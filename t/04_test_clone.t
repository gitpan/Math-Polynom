#################################################################
#
#   $Id: 04_test_clone.t,v 1.3 2007/04/17 19:28:31 erwan_lemonnier Exp $
#
#   @author       erwan lemonnier
#   @description  test method clone
#   @system       pluto
#   @function     base
#   @function     vf
#

use strict;
use warnings;
use Test::More tests => 5;
use lib "../lib/";

use_ok('Math::Polynom');

# test normal polynom
my $p = Math::Polynom->new(1 => 2, 3 => 4);
my $c = $p->clone;

is_deeply($p,$c,"clone() returns same content");

$p->{polynom}->{1} = 0;

is($c->{polynom}->{1},2,"but a different object");
isnt("$c","$p","have different adresses");

# same on empty polynom
$p = Math::Polynom->new;
$c = $p->clone;
isnt("$c","$p","clone of empty polynom have different adresses");
