#################################################################
#
#   Math::Polynom - Operations on polynoms
#
#   $Id: Polynom.pm,v 1.5 2006/12/14 09:47:23 erwan Exp $
#
#   061025 erwan Started implementation
#   061206 erwan Added the secant method
#

package Math::Polynom;

use 5.006;
use strict;
use warnings;
use Carp qw(confess croak);
use Data::Dumper;

use accessors qw(error error_message);

use constant NO_ERROR             => 0;
use constant ERROR_NAN            => 1;
use constant ERROR_MAX_DEPTH      => 2;
use constant ERROR_EMPTY_POLYNOM  => 3;
use constant ERROR_DIVIDE_BY_ZERO => 4;

our $VERSION = '0.02';

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
    my($self,$code,$msg) = @_;
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

    _error("eval() got wrong number of arguments") if (scalar @_ != 2);
    _error("eval() got undefined argument")        if (!defined $x);
    _error("eval()'s argument is not numeric ($x)")     if (!_is_number($x));

    my $r = 0;
    while (my($power,$coef) = each %{$self->{polynom}} ) {
	$r += $coef*($x**$power);
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
    
    $new_guess = $hash{guess}     if (exists $hash{guess});
    $precision = $hash{precision} if (exists $hash{precision});
    $max_depth = $hash{max_depth} if (exists $hash{max_depth});
    
    _error("newton_raphson() got undefined guess")       if (!defined $new_guess);
    _error("newton_raphson() got undefined precision")   if (!defined $precision);
    _error("newton_raphson() got undefined max_depth")   if (!defined $max_depth);
    _error("newton_raphson() got non numeric guess")     if (!_is_number($new_guess));
    _error("newton_raphson() got non numeric precision") if (!_is_number($precision));
    _error("newton_raphson() got non integer max_depth") if ($max_depth !~ /^\d+$/);

    $self->_exception(ERROR_EMPTY_POLYNOM,"cannot find the root of an empty polynom")
	if (scalar keys %{$self->{polynom}} == 0);

    my $derivate = $self->derivate;
    my $old_guess = $new_guess - 2*$precision; # pass the while condition first time
    my $count = 0;

    while (abs($new_guess - $old_guess) > $precision) {
	$old_guess = $new_guess;

	my $dividend = $derivate->eval($old_guess);
	$self->_exception(ERROR_DIVIDE_BY_ZERO,"division by zero at depth $count: polynom's derivate is 0 at $old_guess")
	    if ($dividend == 0);
	
	$new_guess = $old_guess - $self->eval($old_guess)/$dividend;

	$count++;
	$self->_exception(ERROR_MAX_DEPTH,"reached maximum number of iterations [$max_depth] without getting close enough to the root of:\n".
			  $self->stringify."\nwith arguments:\n".Dumper(\%hash))
	    if ($count > $max_depth);
	
	$self->_exception(ERROR_NAN,"not a real number at iteration $count in newton_raphson() on polynom:\n".
			  $self->stringify."\nwith arguments:\n".Dumper(\%hash))
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

    $self->_exception(ERROR_EMPTY_POLYNOM,"cannot find the root of an empty polynom")
	if (scalar keys %{$self->{polynom}} == 0);

    # NOTE: this code is almost a copy/paste from Math::Function::Roots

    my $q0 = $self->eval($p0);
    my $q1 = $self->eval($p1);
    my $p;

    return $p0 if ($q0 == 0);
    return $p1 if ($q1 == 0);

    for (my $depth = 0; $depth <= $max_depth; $depth++) {
	
	if (($q1 - $q0) == 0) {
	    $self->_exception(ERROR_DIVIDE_BY_ZERO,"division by zero at depth $depth with p0=$p0, p1=$p1, q1=q0=$q1\non polynom:\n".
			      $self->stringify."\nwith arguments:\n".Dumper(\%hash));
	}
	   
	$p = ($q1 * $p0 - $p1 * $q0) / ($q1 - $q0);

	if ($p eq 'nan') {
	    $self->_exception(ERROR_NAN,"p is not a real number at iteration $depth in secant() on polynom:\n".
			      $self->stringify."\nwith arguments:\n".Dumper(\%hash));
	}

	$p0 = $p1;
	$q0 = $q1;
	$q1 = $self->eval($p);

	if ($q1 eq 'nan') {
	    $self->_exception(ERROR_NAN,"q1 is not a real number at iteration $depth in secant() on polynom:\n".
			      $self->stringify."\nwith arguments:\n".Dumper(\%hash));
	}
	
	if ($q1 == 0 || abs($p - $p1) <= $precision) {
	    return $p;
	}

	$p1 = $p;
    }

    $self->_exception(ERROR_MAX_DEPTH,"reached maximum number of iterations [$max_depth] without getting close enough to the root of:\n".
		      $self->stringify."\nwith arguments:\n".Dumper(\%hash));
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


=item $p1->B<error>, $p1->B<error_message>

Respectively the error code and error message set by the last method that failed to run
on this polynom. For exemple, if I<newton_raphson> died, you would access the code of the error
with I<error()> and a message describing the context of the error in details with
I<error_message>.

If the polynom has no error, I<error> returns Math::polynom::NO_ERROR and 
I<error_message> returns undef.

=back



=head1 ERROR HANDLING

Each method of a polynom may croak if provided with wrong arguments. Methods that take arguments
do thorough controls on whether the arguments are of the proper type and in the right quantity.
If the error is internal, the method will croak after setting the polynom's error and error_message
to specific values.

Math::Polynom defines a few error codes, returned by the method I<error>:

=over 4

=item B<Math::polynom::NO_ERROR> is the default return value of method I<error>, and is always set to 0.

=item B<Math::polynom::ERROR_NAN> means a method jammed on a complex number.

=item B<Math::polynom::ERROR_DIVIDE_BY_ZERO> means what it says.

=item B<Math::polynom::ERROR_MAX_DEPTH> means the root finding algorithm failed to find a good enough root after the specified maximum number of iterations.

=item B<Math::polynom::ERROR_EMPTY_POLYNOM> means you tried to perform an operation on an empty polynom (such as I<newton_raphson)>

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

$Id: Polynom.pm,v 1.5 2006/12/14 09:47:23 erwan Exp $

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









