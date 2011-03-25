package Bench;
# ABSTRACT: Benchmark running times of Perl code

use 5.010;
use strict;
use warnings;

use Module::Loaded;
use Time::HiRes qw/gettimeofday tv_interval/;

my $bench_called;
my $t0;
my $fmt = "%.4fs";

sub import {
    $t0 = [gettimeofday];

    no strict 'refs';
    my $caller = caller();
    *{"$caller\::bench"} = \&bench;
}

sub bench($;$) {
    my $opts;
    if (ref($_[0]) eq 'CODE') {
        my $sub = shift;
        $opts = shift;
        $opts //= {};
        $opts = {n=>$opts} if ref($opts) ne 'HASH';
        $opts->{subs} //= {CODE=>$sub};
    } elsif (ref($_[0]) eq 'HASH') {
        $opts = shift;
    } else {
        die "Usage: bench(CODEREF, OPTS) or bench(OPTS)";
    }
    die "Please specify one or more subs"
        unless $opts->{subs} && keys %{$opts->{subs}};

    my $use_dumbbench;
    if ($opts->{dumbbench}) {
        $use_dumbbench++;
        require Dumbbench;
    } elsif (!defined $opts->{dumbbench}) {
        $use_dumbbench++ if is_loaded('Dumbbench');
    }

    my @res;
    my $void = !defined(wantarray);
    if ($use_dumbbench) {

        $opts->{dumbbench_options} //= {};
        my $bench = Dumbbench->new(%{ $opts->{dumbbench_options} });
        $bench->add_instances(
            map { Dumbbench::Instance::PerlSub->new(code => $opts->{subs}{$_}) }
                keys %{ $opts->{subs} }
        );
        $bench->run;
        $bench->report;

    } else {

        for my $codename (keys %{ $opts->{subs} }) {
            my $code = $opts->{subs}{$codename};

            my $n = $opts->{n};
            my $ti;

            my $i = 0;
            $t0 = [gettimeofday];

            if (!defined($n)) {
                $code->();
                $ti = tv_interval($t0, [gettimeofday]);
                $i++;
                if ($ti >= 2) {
                    $n = 1;
                } else {
                    $n = -2;
                }
                undef $ti;
            }

            while (1) {
                last if $n >= 0 && $i >= $n;
                $code->();
                $ti = tv_interval($t0, [gettimeofday]);
                $i++;
                last if $n < 0 &&
                    ($ti = tv_interval($t0, [gettimeofday])) >= -$n;
            }
            $ti //= tv_interval($t0, [gettimeofday]);
            my $res = join(
                "",
                (keys(%{$opts->{subs}}) > 1 ? "$codename: " : ""),
                sprintf("%d calls (%.0f/s), $fmt ($fmt/call)",
                        $i, $i/$ti, $ti, ($i ? $ti/$i : 0))
            );
            say $res if $void;
            push @res, $res;
        }

    }

    $bench_called++;
    join("\n", @res);
}

END {
    say sprintf($fmt, tv_interval($t0, [gettimeofday])) unless $bench_called;
}

1;
__END__

=head1 SYNOPSIS

 # time the whole program
 % perl -MBench -e'...'
 0.1234s

 # basic usage of bench()
 % perl -MBench -e'bench sub { ... }'
 iterations=100, total time=1.2340s, time/iter=0.0123s

 # get bench result in a variable
 % perl -MBench -E'my $res = bench sub { ... }'

 # specify bench options
 % perl -MBench -E'bench sub { ... }, 100'
 % perl -MBench -E'bench sub { ... }, {n=>-5, dumbbench=>1}'

 # time multiple codes
 % perl -MBench -E'bench {subs=>{a=>sub {...}, b=>sub {...}}, n=>-2}'

=head1 DESCRIPTION

This module is an alternative to L<Benchmark>. It provides some nice defaults
and a simpler interface. There is only one function, B<bench()>, and it's
exported by default. If bench() is never called, the whole program will be
timed.

This module can be set to utilize L<Dumbbench> as the backend.

=head1 FUNCTIONS

=head2 bench

Syntax:

 bench(CODE)
 bench(CODE, {OPT=>VALUE, ...})
 bench(CODE, INT)               # equivalent to bench(CODE, {n=>1})
 bench({subs=>{...}, ...})

Run Perl code and time it. Exported by default. Will print the result in void
context.

Available options:

=over 4

=item * n => INT

Run the code C<n> times, or if negative, until at least C<n> seconds.

If unspecified, the default behaviour is: if code runs for more than 2 seconds,
it will only be run once (n=1). Otherwise n=-2.

=item * subs => HASHREF

Specify subroutine(s) to time. You normally need not specify this option, unless
you want to time several subroutines instead of just one.

=item * dumbbench => BOOL

If 0, do not use L<Dumbbench> even if it's available. If 1, require and use
L<Dumbbench>. If left undef, will use L<Dumbbench> if it's already loaded.

=item * dumbbench_options => HASHREF

Options that will be passed to Dumbbench constructor, e.g.
{target_rel_precision=>0.005, initial_runs=>20}.

=back


=head1 SEE ALSO

L<Benchmark>

L<Dumbbench>

=cut
