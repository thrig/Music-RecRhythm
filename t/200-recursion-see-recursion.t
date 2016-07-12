#!perl
#
# Recursion

use Test::Most;    # plan is down at bottom
my $deeply = \&eq_or_diff;

use Music::RecRhythm;

my $x = Music::RecRhythm->new( set => [ 2, 2 ] );
my $y = Music::RecRhythm->new( set => [ 1, 1 ] );

$x->next($y);

is( $x->beatproduct, 4, 'product of element counts' );
my $levels = $x->levels;
is( $levels, 2, 'recursion depth' );

# Bumpy_Caps for package-wide global/static variables (perldoc perlstyle)
my @Durations;

$x->recurse(
    sub {
        my ( $rset, $param ) = @_;
        push @{ $Durations[ $param->{level} ] }, $param->{duration};
    }
);

$deeply->( \@Durations, [ [ 2, 2 ], [ 1, 1, 1, 1 ] ], 'recursion results' );

plan tests => 3;
