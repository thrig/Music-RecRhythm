# -*- Perl -*-
#
# rhythms within rhythms within rhythms
#
# Run perldoc(1) on this file for additional documentation.

package Music::RecRhythm;

use 5.10.0;
use strict;
use warnings;

use Moo;
use namespace::clean;
use List::Util qw(sum0);
use Scalar::Util qw(looks_like_number);

our $VERSION = '0.01';

# for ->rebuild a.k.a. object cloning
with 'MooX::Rebuild';

# NOTE a Graph module may be more suitable if more complicated
# structures of rhythm sets need be built up, as this just allows for a
# simple hierarchy (or sequence, depending on how the results of the
# recursion are mapped to time). TODO probably should enforce an isa
# here so recurse doesn't need to check things or blindly dive.
has next => ( is => 'rw', );

has set => (
    is     => 'rw',
    coerce => sub {
        my ($set) = @_;
        die "need a set of positive integers"
          if !Music::RecRhythm->validate_set($set);
        for my $n (@$set) {
            $n = int $n;
        }
        return $set;
    },
    trigger => sub {
        my ( $self, $set ) = @_;
        $self->_set_count( scalar @$set );
        $self->_set_sum( sum0(@$set) );
    },
);
has count => ( is => 'rwp' );
has sum   => ( is => 'rwp' );

# flag to skip the callback (though the rhythm will still be present in
# the recursion)
has is_silent => (
    is      => 'rw',
    default => sub { 0 },
    coerce  => sub { $_[0] ? 1 : 0 },
);

sub BUILD {
    my ( $self, $param ) = @_;
    die "need a set of positive integers" if !exists $param->{set};
}

########################################################################
#
# METHODS

sub beatproduct {
    my ($self) = @_;
    my $product = 1;
    while ($self) {
        $product *= $self->count;
        $self = $self->next;
    }
    return $product;
}

sub levels {
    my ($self) = @_;
    my $levels = 0;
    while ($self) {
        $levels++;
        $self = $self->next;
    }
    return $levels;
}

sub recurse {
    my ( $self, $callback ) = @_;
    _recurse( $self, $callback, $self->beatproduct, 0 );
}

sub _recurse {
    my ( $rset, $callback, $totaltime, $level ) = @_;
    my %param = ( level => $level, totaltime => $totaltime );
    for my $p (qw/next set/) {
        $param{$p} = $rset->$p;
    }
    my $next = $param{next};
    my $sil      = $rset->is_silent;
    my $unittime = $totaltime / $rset->sum;
    for my $n ( 0 .. $#{ $param{set} } ) {
        $param{beat}     = $param{set}[$n];
        $param{index}    = $n;
        my $dur = $param{duration} = int( $unittime * $param{beat} );
        if ( !$sil ) {
            # TODO think about whether and if so how to return output
            # from the callback and then all of the calls to this sub
            $callback->( $rset, \%param );
        }
        _recurse( $next, $callback, $dur, $level + 1 ) if defined $next;
    }
}

sub validate_set {
    my ( $class, $set ) = @_;
    return 0 if !defined $set or ref $set ne 'ARRAY' or !@$set;
    for my $x (@$set) {
        return 0 if !defined $x or !looks_like_number $x or $x < 1;
    }
    return 1;
}

########################################################################
#
# CALLBACKS
#
# TODO put these in a different module file so don't need to load them?
# probably depends on how long the code is...

#sub callback_midi {
#  my ($rset, $param) = @_;
#  ...
#}

1;
__END__

=head1 NAME

Music::RecRhythm - rhythms within rhythms within rhythms

=head1 SYNOPSIS

  use Music::RecRhythm;

  my $one = Music::RecRhythm->new( set => [qw/2 2 1 2 2 2 1/] );

  my $two = $one->rebuild;  # clone the (original) object

  $one->is_silent(1);

  $one->next($two);

  $one->recurse( sub { ... } );

=head1 DESCRIPTION

A utility module for recusive rhythm construction, where a B<set> is
defined as an array reference of positive integers (beats). Multiple
such objects may be linked through the B<next> attribute, which the
B<recurse> method follows. Each B<next> rhythm I<is played out in full
for each beat of the parent> rhythm, though whether these events are
simultaneous or strung out is time is up to the callback code provided
to B<recurse>.

A rhythm may be made silent via the B<is_silent> attribute, in which
case the callback code will not be called for each beat, though B<next>
will be followed as per usual during B<recurse>.

=head1 CONSTRUCTOR

The B<new> method accepts any of the L</ATTRIBUTES>. The B<set>
attribute I<must> be supplied.

=head1 ATTRIBUTES

=over 4

=item B<count>

A read-only count of the beats in the B<set>. Updated when B<set>
is changed.

=item B<is_silent>

Boolean as to whether or not the callback function of B<recurse> will
be invoked for beats of the set. False by default.

=item B<next>

Optional next object to B<recurse> into. While often a
C<Music::RecRhythm> object, any object that supports the necessary
method calls could be used. Recursion will stop should this attribute be
undefined (the default). Probably should not be changed in the middle of
a B<recurse> call.

=item B<set>

An array reference of one or more positive integers (a.k.a. beats). This
attribute I<must> be supplied at construction time.

=item B<sum>

A read-only sum of the beats in the B<set>. Updated when B<set>
is changed.

=back

=head1 METHODS

=over 4

=item B<beatproduct>

Returns the product of the B<count> for each object linked via B<next>.
Used internally by B<recurse> to determine how much time each level
must take.

This method will run forever if a loop is created with B<next> calls.
Don't do that, or use C<alarm> to time the code out. (Or C<extends> the
module and use a hash to track which objects have been seen before.)

=item B<levels>

Returns the number of levels recursion will take place over. May be
useful prior to a B<recurse> call if an array of MIDI tracks (one for
each level) need be created, or similar.

=item B<recurse> I<coderef>

Iterates the beats of the B<set> and recurses through every B<next> for
each beat, calling the I<coderef> unless B<is_silent> is true for the
object. The I<coderef> is passed two arguments, first, the
C<Music::RecRhythm> object which in turn is followed by a hash reference
containing various parameters, including:

=over 4

=item I<beat>

The current beat, a member of the I<set> at the given I<index>.

=item I<duration>

A calculated duration based on the I<beat> and other factors, most
notably the B<beatproduct> over the entire set of linked objects, if
any, such that each B<next> object can be played entirely for each beat
of the parent object without getting into fractional durations.

=item I<index>

Index of the current beat in the I<set>, numbered from 0 on up.

=item I<level>

Level of recursion, C<0> for the first level, C<1> for the second,
and so forth.

=item I<next>

If defined, the B<next> object that will be recursed into.

=item I<set>

Array reference containing the beats of the current set, of which
I<beat> is the current one at index I<index>.

=back

=item B<validate_set> I<set>

Class method. Checks whether a B<set> really is a list of positive
numbers (the C<int> truncation is done elsewhere). The empty set is not
allowed. Used internally by the B<set> attribute.

  Music::RecRhythm->validate_set("cat")      # 0
  Music::RecRhythm->validate_set([qw/1 2/])  # 1

=back

=head1 BUGS

=head2 Reporting Bugs

Please report any bugs or feature requests to
C<bug-music-recrhythm at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Music-RecRhythm>.

Patches might best be applied towards:

L<https://github.com/thrig/Music-RecRhythm>

=head2 Known Issues

Loops created with B<next> calls will run forever as B<beatproduct>,
B<levels>, and B<recurse> do not check for loops created by B<next>
calls. If this is a risk for generated code, wrap these calls with
C<alarm> to abort them should they run for too long (or add loop
detection somehow).

=head1 SEE ALSO

L<MIDI> or L<MIDI::Simple> may assist in the callback code to produce
MIDI during the recursion. Consult the C<eg/> and C<t/> directories
under this module's distribution for example code.

=head1 AUTHOR

thrig - Jeremy Mates (cpan:JMATES) C<< <jmates at cpan.org> >>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016 by Jeremy Mates

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a copy
of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut