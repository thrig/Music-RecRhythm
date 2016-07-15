#!perl
#
# Recursion

use Test::Most;    # plan is down at bottom
my $deeply = \&eq_or_diff;

use Music::RecRhythm;

my @suite = (
    {   sets => [ [ 2, 2 ], [ 1, 1 ] ],
        beatfactor => 4,
        levels     => 2,
        durations  => [ [ 2, 2 ], [ 1, 1, 1, 1 ] ],
    },
    {   sets => [ [ 7, 1 ], [ 2, 1 ] ],
        beatfactor => 168,
        levels     => 2,
        durations  => [ [ 147, 21 ], [ 98, 49, 14, 7 ] ],
    },
);

for my $sref (@suite) {
    my @rrs;
    for my $set ( @{ $sref->{sets} } ) {
        push @rrs, Music::RecRhythm->new( set => $set );
        $rrs[-2]->next( $rrs[-1] ) if @rrs > 1;
    }
    is( $rrs[0]->beatfactor, $sref->{beatfactor}, 'beatfactor' );
    is( $rrs[0]->levels,     $sref->{levels},     'levels' );
    my @durations;
    $rrs[0]->recurse(
        sub {
            my ( $rset, $param, $durs ) = @_;
            push @{ $durs->[ $param->{level} ] }, $param->{duration};
        },
        \@durations
    );
    $deeply->( \@durations, $sref->{durations}, 'recursion results' );
}

plan tests => 3 * @suite;
