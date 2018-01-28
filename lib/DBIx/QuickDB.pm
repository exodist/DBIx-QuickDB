package DBIx::QuickDB;
use strict;
use warnings;

our $VERSION = '0.000002';

use Carp;
use List::Util qw/first/;
use File::Temp qw/tempdir/;
use Module::Pluggable search_path => 'DBIx::QuickDB::Driver', max_depth => 4, require => 0;

require constant;

my %CACHE;

sub import {
    my $class = shift;
    my ($name, @args) = @_;

    return unless defined $name;

    my $spec = @args > 1 ? {@args} : $args[0];

    my $db = $class->build_db($name, $spec);

    my $caller = caller;
    no strict 'refs';
    *{"$caller\::$name"} = sub() { $db };
}

sub build_db {
    my $class = shift;
    my $name = shift(@_) unless ref($_[0]);
    my $spec = shift(@_) || {};

    return $CACHE{$name}->{inst}
        if $name && $CACHE{$name} && !$spec->{nocache};

    if ($spec->{dir}) {
        $spec->{autostop} = $spec->{autostart} unless defined $spec->{autostop};
    }
    else {
        $spec->{bootstrap} = 1;
        $spec->{cleanup}   = 1 unless defined $spec->{cleanup};
        $spec->{dir}       = tempdir('DB-QUICK-XXXXXXXX', CLEANUP => 0, TMPDIR => 1);
        $spec->{autostart} = 1;
    }

    my $driver;
    my $drivers = $spec->{driver} ? [$spec->{driver}] : delete $spec->{drivers} || [$class->plugins];
    my %nope;
    for my $d (@$drivers) {
        my ($v, $fqn, $why) = $class->check_driver($d, $spec);
        if ($v) {
            $driver = $fqn;
            last;
        }
        $nope{$d} = $why;
    }

    unless ($driver) {
        my @err = "== Could not find a viable driver from the following ==";
        for my $d (keys %nope) {
            push @err => "\n=== $d ===", $nope{$d};
        }

        confess join "\n" => @err, "", "====================", "", "Aborting";
    }

    my $inst = $driver->new(
        dir       => $spec->{dir},
        cleanup   => $spec->{cleanup},
        autostart => $spec->{autostart},
        autostop  => $spec->{autostop},
        verbose   => $spec->{verbose},
    );

    $CACHE{$name} = {spec => $spec, inst => $inst} if $name && !$spec->{nocache};

    $inst->bootstrap if $spec->{bootstrap};
    $inst->start     if $spec->{autostart};

    if (my $sql = $spec->{load_sql}) {
        $sql = $sql->{$driver} if ref($sql) eq 'HASH';
        $sql = [$sql] unless ref $sql;
        $inst->load_sql($_) for @$sql;
    }

    return $inst;
}

sub check_driver {
    my $class = shift;
    my ($d, $spec) = @_;

    $d = "DBIx::QuickDB::Driver::$d" unless $d =~ s/^\+// || $d =~ m/^DBIx::QuickDB::Driver::/;

    my $f = $d;
    $f =~ s{::}{/}g;
    $f .= ".pm";
    require $f;

    my ($v, $why) = $d->viable($spec);

    return ($v, $d, $why);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::QuickDB - Quickly start a db server.

=head1 DESCRIPTION

This library makes it easy to spin up a temporary database server for any
supported driver. PostgreSQL and MySQL are the initially supported drivers.

=head1 SYNOPSIS

    use DBIx::QuickDB MYSQL_DB => {driver => 'MySQL'};
    use DBIx::QuickDB PSQL_DB  => {driver => 'PostgreSQL'};

    my $m_dbh = MYSQL_DB->connect;
    my $p_dbh = PSQL_DB->connect;

    ...

=head1 TODO - MORE DOCS

This is a VERY alpha release, more docs to come, API may change completely.

=head1 SOURCE

The source code repository for DBIx-QuickDB can be found at
F<https://github.com/exodist/DBIx-QuickDB/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2018 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
