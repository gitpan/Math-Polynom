#################################################################
#
#   Math::Polynom - Operations on polynoms
#
#   $Id: Polynom.pm,v 1.9 2007/01/03 14:56:36 erwan Exp $
#
#   061025 erwan Started implementation
#   061206 erwan Added the secant method
#   061214 erwan Added Brent's method
#

package Math::Polynom;

use 5.006;
use strict;
use warnings;
use Carp qw(confess croak);
use Data::Dumper;

use accessors qw(error error_message iterations xpos xneg);

use constant NO_ERROR             => 0;
use constant ERROR_NAN            => 1;
use constant ERROR_MAX_DEPTH      => 2;
use constant ERROR_EMPTY_POLYNOM  => 3;
use constant ERROR_DIVIDE_BY_ZERO => 4;
use constant ERROR_WRONG_SIGNS    => 5;

our $VERSION = '0.04';

#----------------------------------------------------------------
#
#   _add_monom - add a monom to a polynom, ie a $coef**$power
#

sub _add_monom {
    my($self,$coef,$power) = @_;

    if (exists $self->{polynom}->{$power}) {
	$self->{polynom}->{$power} += $coef;
    } else {
	$self->{polynom}->{$power} = $coef;
    }
    return $self;
}

#----------------------------------------------------------------
#
#   _clean - remove terms with zero as coefficient
#

sub _clean {
    my $self = shift;

    while (my($power,$coef) = each %{$self->{polynom}}) {
	if ($coef == 0) {
	    delete $self->{polynom}->{$power};
	}
    }
    
    return $self;
}

#----------------------------------------------------------------
#
#   _is_number - check that variable is a number
#

sub _is_number {
    my $n = shift;
    return 0 if (!defined $n);
    return 0 if (ref $n ne '');
    return $n =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;
}

#----------------------------------------------------------------
#
#   _error - die nicely
#

sub _error {
    my $msg = shift;
    croak __PACKAGE__." ERROR: $msg\n";
}

sub _exception {
    my($self,$code,$msg,$args) = @_;

    $msg = "ERROR: $msg\nwith polynom:\n".$self->stringify."\n";
    if (defined $args) {
	$msg .= "with arguments:\n".Dumper($args);
    }
    $msg .= "at iteration ".$self->iterations."\n";

    $self->error_message($msg);
    $self->error($code);

    croak $self->error_message;
}

#################################################################
#
#
#   PUBLIC
#
#
#################################################################

#----------------------------------------------------------------
#
#   new - construct a new polynom
#

sub new {
    my($pkg,@args) = @_;
    $pkg = ref $pkg || $pkg;

    _error("new() got odd number of arguments. can not be a hash") if (scalar(@args) % 2);

    my %hash = @args;
    foreach my $n (@args) {
	_error("at least one argument of new() is not numeric:\n".Dumper(\%hash)) if (!_is_number($n));
    }

    my $self = bless({polynom => \%hash},$pkg)->_clean;
    $self->error(NO_ERROR);
    $self->iterations(0);
    return $self;
}

#----------------------------------------------------------------
#
#   clone - return a clone of self
#

sub clone {
    my $self = shift;
    return __PACKAGE__->new(%{$self->{polynom}});
}

#----------------------------------------------------------------
#
#   stringify - return current polynom as a string
#

sub stringify {
    my $self = shift;
    return join(" + ", map { $self->{polynom}->{$_}."*x^".$_ } reverse sort keys %{$self->{polynom}});
}

#----------------------------------------------------------------
#
#   derivate - return the derivate 
#

sub derivate {
    my $self = shift;
    my $result = __PACKAGE__->new();
    while (my($power,$coef) = each %{$self->{polynom}} ) {
	$result->_add_monom($coef*$power,$power-1);
    }
    return $result->_clean;
}

#----------------------------------------------------------------
#
#   eval - evaluate the polynom on a given value, return result
#

sub eval {
    my($self,$x) = @_;

    _error("eval() got wrong number of arguments")  if (scalar @_ != 2);
    _error("eval() got undefined argument")         if (!defined $x);
    _error("eval()'s argument is not numeric ($x)") if (!_is_number($x));

    my $r = 0;
    while (my($power,$coef) = each %{$self->{polynom}} ) {
	$r += $coef*($x**$power);
    }

    if ($r ne 'nan') {
	if (!defined $self->xpos && $r > 0) {
	    $self->xpos($x);
	} elsif (!defined $self->xneg && $r < 0) {
	    $self->xneg($x);
	}
    }

    return $r;
}

#----------------------------------------------------------------
#
#   add - add a polynom/number to current polynom
#

sub add {
    my($self,$p) = @_;
    
    _error("add() got wrong number of arguments") if (scalar @_ != 2);
    _error("add() got undefined argument")        if (!defined $p);

    # adding 2 polynoms
    if (ref $p eq __PACKAGE__) {
	my $result = $self->clone;
	while (my($power,$coef) = each %{$p->{polynom}}) {
	    $result->_add_monom($coef,$power);
	}	
	return $result->_clean;
    }

    # adding a constant to a polynom    
    _error("add() got non numeric argument") if (!_is_number($p));

    return $self->clone->_add_monom($p,0)->_clean;
}

#----------------------------------------------------------------
#
#   minus - substract a polynom/number to current polynom
#

sub minus {
    my($self,$p) = @_;

    _error("minus() got wrong number of arguments") if (scalar @_ != 2);
    _error("minus() got undefined argument")        if (!defined $p);
    
    if (ref $p eq __PACKAGE__) {
	return $self->clone->add($p->negate)->_clean;
    }

    _error("minus() got non numeric argument") if (!_is_number($p));

    return $self->clone->_add_monom(-$p,0)->_clean;
}

#----------------------------------------------------------------
#
#   negate - negate current polynom
#

sub negate {
    my $self = shift;
    return __PACKAGE__->new(map { $_, - $self->{polynom}->{$_} } keys %{$self->{polynom}})->_clean;
}

#----------------------------------------------------------------
#
#   multiply - multiply current polynom with a polynom/number
#

sub multiply {
    my($self,$p) = @_;

    _error("multiply() got wrong number of arguments") if (scalar @_ != 2);
    _error("multiply() got undefined argument")        if (!defined $p);

    if (ref $p eq __PACKAGE__) {
	my $result = __PACKAGE__->new;
	while (my($power1,$coef1) = each %{$self->{polynom}}) {
	    while (my($power2,$coef2) = each %{$p->{polynom}}) {
		$result->_add_monom($coef1 * $coef2, $power1 + $power2);
	    }
	}	
	return $result->_clean;
    }
    
    _error("multiply() got non numeric argument") if (!_is_number($p));

    return __PACKAGE__->new(map { $_, $p * $self->{polynom}->{$_} } keys %{$self->{polynom}})->_clean;
}

#----------------------------------------------------------------
#
#   divide - divide the current polynom with a float
#

sub divide {
    my($self,$x) = @_;

    _error("divide() got wrong number of arguments") if (scalar @_ != 2);
    _error("divide() got undefined argument")        if (!defined $x);
    _error("divide() got non numeric argument")      if (!_is_number($x));
    _error("cannot divide by 0")                     if ($x == 0);

    return __PACKAGE__->new(map { $_, $self->{polynom}->{$_}/$x } keys %{$self->{polynom}})->_clean;
}

#----------------------------------------------------------------
#
#   newton_raphson - attempt to find a polynom's root with Newton Raphson
#

sub newton_raphson {
    my($self,%hash) = @_;
    my $new_guess = 1;
    my $precision = 0.1;
    my $max_depth = 100;
    
    $self->iterations(0);
    $self->error(NO_ERROR);

    $new_guess = $hash{guess}     if (exists $hash{guess});
    $precision = $hash{precision} if (exists $hash{precision});
    $max_depth = $hash{max_depth} if (exists $hash{max_depth});
    
    _error("newton_raphson() got undefined guess")       if (!defined $new_guess);
    _error("newton_raphson() got undefined precision")   if (!defined $precision);
    _error("newton_raphson() got undefined max_depth")   if (!defined $max_depth);
    _error("newton_raphson() got non numeric guess")     if (!_is_number($new_guess));
    _error("newton_raphson() got non numeric precision") if (!_is_number($precision));
    _error("newton_raphson() got non integer max_depth") if ($max_depth !~ /^\d+$/);

    $self->_exception(ERROR_EMPTY_POLYNOM,"cannot find the root of an empty polynom",\%hash)
	if (scalar keys %{$self->{polynom}} == 0);

    my $derivate = $self->derivate;
    my $old_guess = $new_guess - 2*$precision; # pass the while condition first time

    while (abs($new_guess - $old_guess) > $precision) {
	$old_guess = $new_guess;

	my $dividend = $derivate->eval($old_guess);
	$self->_exception(ERROR_DIVIDE_BY_ZERO,"division by zero: polynomial's derivate is 0 at $old_guess",\%hash)
	    if ($dividend == 0);
	
	$new_guess = $old_guess - $self->eval($old_guess)/$dividend;

	$self->iterations($self->iterations + 1);
	$self->_exception(ERROR_MAX_DEPTH,"reached maximum number of iterations [$max_depth] without getting close enough to the.",\%hash)
	    if ($self->iterations > $max_depth);
	
	$self->_exception(ERROR_NAN,"new guess is not a real number in newton_raphson().",\%hash)
	    if ($new_guess eq 'nan');
    }
    
    return $new_guess;
}

#----------------------------------------------------------------
#
#   secant - implement the Secant algorithm to approximate the root of this polynom
#

sub secant {
    my($self,%hash) = @_;
    my $precision = 0.1;
    my $max_depth = 100;
    my($p0,$p1);

    $self->iterations(0);
    $self->error(NO_ERROR);    

    $precision = $hash{precision} if (exists $hash{precision});
    $max_depth = $hash{max_depth} if (exists $hash{max_depth});
    $p0        = $hash{p0}        if (exists $hash{p0});
    $p1        = $hash{p1}        if (exists $hash{p1});

    _error("secant() got undefined precision")      if (!defined $precision);
    _error("secant() got undefined max_depth")      if (!defined $max_depth);
    _error("secant() got non numeric precision")    if (!_is_number($precision));
    _error("secant() got non integer max_depth")    if ($max_depth !~ /^\d+$/);
    _error("secant() got undefined p0")             if (!defined $p0);
    _error("secant() got undefined p1")             if (!defined $p1);
    _error("secant() got non numeric p0")           if (!_is_number($p0));
    _error("secant() got non numeric p1")           if (!_is_number($p1));    
    _error("secant() got same value for p0 and p1") if ($p0 == $p1);

    $self->_exception(ERROR_EMPTY_POLYNOM,"cannot find the root of an empty polynom",\%hash)
	if (scalar keys %{$self->{polynom}} == 0);

    # NOTE: this code is almost a copy/paste from Math::Function::Roots, I just added exception handling

    my $q0 = $self->eval($p0);
    my $q1 = $self->eval($p1);
    my $p;

    return $p0 if ($q0 == 0);
    return $p1 if ($q1 == 0);

    for (my $depth = 0; $depth <= $max_depth; $depth++) {

	$self->iterations($depth);

	$self->_exception(ERROR_DIVIDE_BY_ZERO,"division by zero with p0=$p0, p1=$p1, q1=q0=$q1 in secant()",\%hash)	
	    if (($q1 - $q0) == 0);
	   
	$p = ($q1 * $p0 - $p1 * $q0) / ($q1 - $q0);

	$self->_exception(ERROR_NAN,"p is not a real number in secant()",\%hash)
	    if ($p eq 'nan');

	$p0 = $p1;
	$q0 = $q1;
	$q1 = $self->eval($p);

	$self->_exception(ERROR_NAN,"q1 is not a real number in secant()",\%hash)
	    if ($q1 eq 'nan');

	return $p if ($q1 == 0 || abs($p - $p1) <= $precision);

	$p1 = $p;
    }

    $self->_exception(ERROR_MAX_DEPTH,"reached maximum number of iterations [$max_depth] without getting close enough to the root in secant()",\%hash);
}

#----------------------------------------------------------------
#
#   brent - implement Brent's method to approximate the root of this polynom
#

sub brent {
    my($self,%hash) = @_;
    my $precision = 0.1;
    my $max_depth = 100;
    my $mflag;
    my($a,$b,$c,$s,$d);
    my($f_a,$f_b,$f_c,$f_s);
    
    $self->iterations(0);
    $self->error(NO_ERROR);

    $precision = $hash{precision} if (exists $hash{precision});
    $max_depth = $hash{max_depth} if (exists $hash{max_depth});
    $a         = $hash{a}         if (exists $hash{a});
    $b         = $hash{b}         if (exists $hash{b});

    _error("brent() got undefined precision")      if (!defined $precision);
    _error("brent() got undefined max_depth")      if (!defined $max_depth);
    _error("brent() got non numeric precision")    if (!_is_number($precision));
    _error("brent() got non integer max_depth")    if ($max_depth !~ /^\d+$/);
    _error("brent() got undefined a")              if (!defined $a);
    _error("brent() got undefined b")              if (!defined $b);
    _error("brent() got non numeric a")            if (!_is_number($a));
    _error("brent() got non numeric b")            if (!_is_number($b));    
    _error("brent() got same value for a and b")   if ($a == $b);

    $self->_exception(ERROR_EMPTY_POLYNOM,"cannot find the root of an empty polynom in brent()",\%hash)
	if (scalar keys %{$self->{polynom}} == 0);
    
    # The following is an implementation of Brent's method as described on wikipedia
    # variable names are chosen to match the pseudocode listed on wikipedia
    # There are a few differences between this code and the pseudocode on wikipedia though...

    $f_a = $self->eval($a);
    $f_b = $self->eval($b);
    
    # if the polynom evaluates to a complex number on $a or $b (ex: square root, when $a = -1)
    $self->_exception(ERROR_NAN,"polynom is not defined on interval [a=$a, b=$b] in brent()",\%hash)
	if ($f_a eq 'nan' || $f_b eq 'nan');
    
    # did we hit the root by chance?
    return $a if ($f_a == 0);
    return $b if ($f_b == 0);

    # $a and $b should be chosen so that poly($a) and poly($b) have opposite signs. 
    # It is a prerequisite for the bisection part of Brent's method to work
    $self->_exception(ERROR_WRONG_SIGNS,"polynom does not have opposite signs at a=$a and b=$b in brent()",\%hash)
	if ($f_a*$f_b > 0);

    # eventually swap $a and $b (don't forget to even switch f(c))
    if (abs($f_a) < abs($f_b)) {
	($a,$b) = ($b,$a);
	($f_a,$f_b) = ($f_b,$f_a);
    }
    
    $c = $a;
    $f_c = $f_a;

    $mflag = 1;
    
    # repeat while we haven't found the root nor are close enough to it
    while ($f_b != 0 && abs($b - $a) > $precision) {
	
	# did we reach the maximum number of iterations?
	$self->_exception(ERROR_MAX_DEPTH,"reached maximum number of iterations [$max_depth] without getting close enough to the root in brent()",\%hash)	
	    if ($self->iterations > $max_depth);

	# evaluate f(a), f(b) and f(c) if necessary
	if ($self->iterations != 0) {
	    $f_a = $self->eval($a);
	    $f_b = $self->eval($b);
	    $f_c = $self->eval($c);

	    $self->_exception(ERROR_NAN,"polynom leads to an imaginary number on a=$a in brent()",\%hash) if ($f_a eq 'nan');
	    $self->_exception(ERROR_NAN,"polynom leads to an imaginary number on b=$b in brent()",\%hash) if ($f_b eq 'nan');
	    $self->_exception(ERROR_NAN,"polynom leads to an imaginary number on c=$c in brent()",\%hash) if ($f_c eq 'nan');
	}

	# calculate the next root candidate
	if ($f_a == $f_b) {
	    # we should not be able to get $f_b == $f_a since it's a prerequisite of the method. that would be a bug
	    _error("BUG: got same values for polynom at a=$a and b=$b:\n".$self->stringify);

	} elsif ( ($f_a != $f_c) && ($f_b != $f_c) ) {
	    # use quadratic interpolation
	    $s = ($a*$f_b*$f_c)/(($f_a - $f_b)*($f_a - $f_c)) +
		($b*$f_a*$f_c)/(($f_b - $f_a)*($f_b - $f_c)) +
		($c*$f_a*$f_b)/(($f_c - $f_a)*($f_c - $f_b));
	} else {
	    # otherwise use the secant
	    $s = $b - $f_b*($b - $a)/($f_b - $f_a);
	}
	
	# now comes the main difference between Brent's method and Dekker's method: we want to use bisection when appropriate
	if ( ( ($s < (3*$a+$b)/4) && ($s > $b) ) ||
	     ( $mflag  && (abs($s-$b) >= (abs($b-$c)/2)) ) ||
	     ( !$mflag && (abs($s-$b) >= (abs($c-$d)/2)) ) ) {
	    # in that case, use the bisection to get $s
	    $s = ($a + $b)/2;
	    $mflag = 1;
	} else {
	    $mflag = 0;
	}
	
	# calculate f($s)
	$f_s = $self->eval($s);
	
	$self->_exception(ERROR_NAN,"polynom leads to an imaginary number on s=$s in brent()",\%hash) if ($f_s eq 'nan');
	
	$d = $c;
	$c = $b;
	$f_c = $f_b;
	
	if ($f_a*$f_s <= 0) {
	    # important that b=s if f(s)=0 since the while loop checks f(b)
	    # if f(a)=0, and f(b)!=0, then a and b will be swaped and we will therefore have f(b)=0
	    $b = $s;
	    $f_b = $f_s;
	} else {
	    $a = $s;
	    $f_a = $f_s;
	}

	# eventually swap $a and $b
	if (abs($f_a) < abs($f_b)) {
	    # in the special case when 
	    ($a,$b) = ($b,$a);
	    ($f_a,$f_b) = ($f_b,$f_a);
	}

	$self->iterations($self->iterations + 1);
    }
    
    return $b;
}

1;

__END__

=head1 NAME

Math::Polynom - Operations on polynoms

=head1 SYNOPSIS

    use Math::Polynom;

To create the polynom 'x^3 + 4*x^2 + 1', write:

    my $p1 = Math::Polynom->new(3 => 1, 2 => 4, 0 => 1);

To create '3.5*x^4.2 + 1.78*x^0.9':

    my $p2 = Math::Polynom->new(4.2 => 3.5, 0.9 => 1.78);

Common operations:

    my $p3 = $p1->multiply($p2); # multiply 2 polynoms
    my $p3 = $p1->multiply(4.5); # multiply a polynom with a constant

    my $p3 = $p1->add($p2);      # add 2 polynoms
    my $p3 = $p1->add(3.6);      # add a constant to a polynom
    
    my $p3 = $p1->minus($p2);    # substract 2 polynoms
    my $p3 = $p1->minus(1.5);    # substract a constant to a polynom

    my $p3 = $p1->negate();      # negate a polynom

    my $p3 = $p1->divide(3.2);   # divide a polynom by a constant

    my $v = $p1->eval(1.35);     # evaluate the polynom on a given value

    my $p3 = $p1->derivate();    # return the derivate of a polynom

    print $p1->stringify."\n";   # stringify polynom

To try to find a root to a polynom using the Newton Raphson method:

    my $r;
    eval { $r = $p1->newton_raphson(guess => 2, precision => 0.001); };
    if ($@) {
        if ($p1->error) {
            # that's an internal error
            if ($p1->error == Math::Polynom::ERROR_NAN) {
                # bumped on a complex number
            }
        } else {
            # either invalid arguments (or a bug in solve())
        }
    }

Same with the secant method:

    eval { $r = $p1->secant(p0 => 0, p2 => 2, precision => 0.001); };


=head1 DESCRIPTION

What! Yet another module to manipulate polynoms!!
No, don't worry, there is a good reason for this one ;)

I needed (for my work at a large financial institution) a robust way to compute the internal rate of return (IRR)
of various cashflows.
An IRR is typically obtained by solving a usually ughly looking polynom of one variable with up to hundreds of 
coefficients and non integer powers (ex: powers with decimals). I also needed thorough fault handling.
Other CPAN modules providing operations on polynoms did not support those requirements. 

If what you need is to manipulate simple polynoms with integer powers, without risks of failures,
check out Math::Polynomial since it provides a more complete api than this one.

An instance of Math::Polynom is a representation of a 1-variable polynom.
It supports a few basic operations specific to polynoms such as addition, substraction and multiplication. 

Math::Polynom also implements various root finding algorithms (which is kind of 
the main purpose of this module) such as the Newton Raphson and Secant methods.


=head1 API

=over 4

=item $p1 = B<new(%power_coef)>

Create a new Math::Polynom. Each key in the hash I<%power_coef> is a power
and each value the corresponding coefficient.

=item $p3 = $p1->B<clone()>

Return a clone of the current polynom.

=item $p3 = $p1->B<add($p2)>

Return a new polynom that is the sum of the current polynom with the polynom I<$p2>.
If I<$p2> is a scalar, we add it to the current polynom as a numeric constant.

Croaks if provided with weird arguments.

=item $p3 = $p1->B<minus($p2)>

Return a new polynom that is the current polynom minus the polynom I<$p2>.
If I<$p2> is a scalar, we substract it from the current polynom as a numeric constant.

Croaks if provided with weird arguments.

=item $p3 = $p1->B<multiply($p2)>

Return a new polynom that is the current polynom multiplied by I<$p2>.
If I<$p2> is a scalar, we multiply all the coefficients in the current polynom with it.

Croaks if provided with weird arguments.

=item $p3 = $p1->B<negate()>

Return a new polynom in which all coefficients have the negated sign of those in the current polynom.

=item $p3 = $p1->B<divide($float)>

Return a new polynom in which all coefficients are equal to those of the current polynom divided by the number I<$float>.

Croaks if provided with weird arguments.

=item $p3 = $p1->B<derivate()>

Return a new polynom that is the derivate of the current polynom.

=item $v = $p1->B<eval($float)>

Evaluate the current polynom on the value I<$float>.

If you call I<eval> with a negative value that would yield a complex (non real) result,
I<eval> will no complain but return the string 'nan'.

Croaks if provided with weird arguments.

=item $s = $p1->B<stringify()>

Return a basic string representation of the current polynom. For exemple '3*x^5 + 2*x^2 + 1*x^0'.

=item $r = $p1->B<< newton_raphson(guess => $float1, precision => $float2, max_depth => $integer) >>

Uses the Newton Raphson algorithm to approximate a root for this polynom. Beware that this require
your polynom AND its derivate to be continuous.
Starts the search with I<guess> and returns the root when the difference between two
consecutive estimations of the root is smaller than I<precision>. Make at most I<max_depth>
iterations.

If I<guess> is omitted, 1 is used as default.
If I<precision> is omitted, 0.1 is used as default.
If I<max_depth> is omitted, 100 is used as default.

I<newton_raphson> will fail (croak) in a few cases: If the successive approximations of the root 
still differ with more than I<precision> after I<max_depth> iterations, I<newton_raphson> dies,
and C<< $p1->error >> is set to the code Math::Polynom::ERROR_MAX_DEPTH. If an approximation 
is not a real number, I<newton_raphson> dies and C<< $p1->error >> is set to the code Math::Polynom::ERROR_NAN.
If the polynom is empty, I<newton_raphson> dies and C<< $p1->error >> is set to the code 
Math::Polynom::ERROR_EMPTY_POLYNOM.

I<newton_raphson> will also croak if provided with weird arguments.

Exemple:

    eval { $p->newton_raphson(guess => 1, precision => 0.0000001, max_depth => 50); };
    if ($@) {
        if ($p->error) {
            if ($p->error == Math::Polynom::ERROR_MAX_DEPTH) {
                # do something wise
            } elsif ($p->error == Math::Polynom::ERROR_MAX_DEPTH) {
                # do something else
            } else { # empty polynom
                die "BUG!";
            }
        } else {
            die "newton_raphson died for unknown reason";
        }
    }


=item $r = $p1->B<< secant(p0 => $float1, p1 => $float2, precision => $float3, max_depth => $integer) >>

Use the secant method to approximate a root for this polynom. I<p0> and I<p1> are the two start values
to initiate the search, I<precision> and I<max_depth> have the same meaning as for I<newton_raphson>.

The polynom should be continuous. Therefore, the secant method might fail on polynomial having monoms
with degrees lesser than 1.

If I<precision> is omitted, 0.1 is used as default.
If I<max_depth> is omitted, 100 is used as default.

I<secant> will fail (croak) in a few cases: If the successive approximations of the root 
still differ with more than I<precision> after I<max_depth> iterations, I<secant> dies,
and C<< $p1->error >> is set to the code Math::Polynom::ERROR_MAX_DEPTH. If an approximation 
is not a real number, I<secant> dies and C<< $p1->error >> is set to the code Math::Polynom::ERROR_NAN.
If the polynom is empty, I<secant> dies and C<< $p1->error >> is set to the code 
Math::Polynom::ERROR_EMPTY_POLYNOM.

I<secant> will also croak if provided with weird arguments.


=item $r = $p1->B<< brent(a => $float1, b => $float2, precision => $float3, max_depth => $integer) >>

Use Brent's method to approximate a root for this polynom. I<a> and I<b> are two floats such that 
I<< p1->eval(a) >> and I<< p1->eval(b) >> have opposite signs. 
I<precision> and I<max_depth> have the same meaning as for I<newton_raphson>.

The polynom should be continuous on the interval [a,b].

Brent's method is considered to be one of the most robust root finding methods. It alternatively
uses the secant, inverse quadratic interpolation and bisection to find the next root candidate
at each iteration, making it a robust but quite fast converging method.

The difficulty with Brent's method consists in finding the start values a and b for which
the polynome evaluates to opposite signs. This is somewhat simplified in Math::Polynom
by the fact that I<eval()> automatically sets I<xpos()> and I<xneg()> when possible.

If I<precision> is omitted, 0.1 is used as default.
If I<max_depth> is omitted, 100 is used as default.

I<brent> will fail (croak) in a few cases: If the successive approximations of the root 
still differ with more than I<precision> after I<max_depth> iterations, I<brent> dies,
and C<< $p1->error >> is set to the code Math::Polynom::ERROR_MAX_DEPTH. If an approximation 
is not a real number, I<brent> dies and C<< $p1->error >> is set to the code Math::Polynom::ERROR_NAN.
If the polynom is empty, I<brent> dies and C<< $p1->error >> is set to the code 
Math::Polynom::ERROR_EMPTY_POLYNOM. If provided with a and b that does not lead to values
having opposite signs, I<brent> dies and C<< $p1->error >> is set to the code Math::Polynom::ERROR_WRONG_SIGNS.

I<brent> will also croak if provided with weird arguments.


=item $p1->B<error>, $p1->B<error_message>

Respectively the error code and error message set by the last method that failed to run
on this polynom. For exemple, if I<newton_raphson> died, you would access the code of the error
with I<error()> and a message describing the context of the error in details with
I<error_message>.

If the polynom has no error, I<error> returns Math::polynom::NO_ERROR and 
I<error_message> returns undef.


=item $p1->B<iterations>

Return the number of iterations it took to find the polynom's root. Must be called
after calling one of the root finding methods.


=item $p1->B<xpos>, $p1->B<xneg>

Each time I<eval> is called, it checks whether we know a value xpos for which the polynom
evaluates to a positive value. If not and if the value provided to I<eval> lead to a positive
result, this value is stored in I<xpos>. Same thing with I<xneg> and negative results.

This comes in handy when you wish to try the Brent method after failing with the secant
or Newton methods. If you are lucky, those failed attempts will have identified both a
xpos and xneg that you can directly use as a and b in I<brent()>.


=back


=head1 ERROR HANDLING

Each method of a polynom may croak if provided with wrong arguments. Methods that take arguments
do thorough controls on whether the arguments are of the proper type and in the right quantity.
If the error is internal, the method will croak after setting the polynom's error and error_message
to specific values.

Math::Polynom defines a few error codes, returned by the method I<error>:

=over 4

=item B<Math::polynom::NO_ERROR> is the default return value of method I<error>, and is always set to 0.

=item B<Math::polynom::ERROR_NAN> means the function jammed on a complex number. Most likely because your polynom is not continuous on the search interval.

=item B<Math::polynom::ERROR_DIVIDE_BY_ZERO> means what it says.

=item B<Math::polynom::ERROR_MAX_DEPTH> means the root finding algorithm failed to find a good enough root after the specified maximum number of iterations.

=item B<Math::polynom::ERROR_EMPTY_POLYNOM> means you tried to perform an operation on an empty polynom (such as I<newton_raphson)>

=item B<Math::polynom::ERROR_WRONG_SIGNS> means that the polynom evaluates to values having the same signs instead of opposite signs on the boundaries of the interval you provided to start the search of the root (ex: Brent's method)

=back

=head1 BUGS AND LIMITATIONS

This module is built for robustness in order to run in requiring production environments. 
Yet it has one limitation: due to Perl's 
inability at handling large floats, root finding algorithms will get lost if starting on a guess
value that is too far from the root. Example:

    my $p = Math::Polynom->new(2 => 1, 1 => -2, 0 => 1); # x^2 -2*x +1
    $p->newton_raphson(guess => 100000000000000000); 
    # returns 1e17 as the root



=head1 SEE ALSO

See Math::Calculus::NewtonRaphson, Math::Polynomial, Math::Function::Roots.

=head1 VERSION

$Id: Polynom.pm,v 1.9 2007/01/03 14:56:36 erwan Exp $

=head1 THANKS

Thanks to Spencer Ogden who wrote the implementation of the Secant algorithm in his module Math::Function::Roots. 

=head1 AUTHOR

Erwan Lemonnier C<< <erwan@cpan.org> >>

=head1 COPYRIGHT AND LICENSE

This code is distributed under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTY

This is free code and comes with no warranty. The author declines any personal 
responsibility regarding the use of this code or the consequences of its use.

=cut









