package Test2::Tools::QuickDB;
use strict;
use warnings;

our $VERSION = '0.000004';

use Test2::API qw/context/;
use DBIx::QuickDB();

use Importer Importer => 'import';

our @EXPORT = qw/get_db_or_skipall get_db skipall_unless_can_db/;

sub skipall_unless_can_db {
    my ($driver, $spec) = @_;

    $spec ||= {bootstrap => 1, autostart => 1, load_sql => 1};

    my $ctx = context();

    my ($v, $fqn, $why) = DBIx::QuickDB->check_driver($driver, $spec);

    if ($v) {
        $ctx->release;
        return $fqn;
    }

    $ctx->plan(0, 'SKIP' => "$driver db driver is not viable\n$why");
    $ctx->release;

    return;
}

sub get_db {
    # Get a context in case anything below here has testing code.
    my $ctx = context();

    my $db = DBIx::QuickDB->build_db(@_);

    $ctx->release;

    return $db;
}

sub get_db_or_skipall {
    my @args = @_;

    my $ctx = context();

    my $db;
    my $ok = eval { $db = DBIx::QuickDB->build_db(@args) };
    my $err = $@;

    unless($ok) {
        if ($err =~ m/(Could not find a viable driver)/) {
            my $name = shift(@_) unless ref($_[0]);
            my $spec = shift(@_) || {};

            my $msg = $1;
            if (my $driver = $spec->{driver}) {
                $msg .= " ($driver)";
            }
            elsif (my $drivers = $spec->{drivers}) {
                $msg .= " (" . join(", " => @$drivers) . ")";
            }
            else {
                $msg .= " (ANY)";
            }
            $ctx->plan(0, SKIP => $msg);
            $ctx->release;
            return;
        }
        die $err;
    }

    $ctx->release;

    return $db;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Tools::QuickDB - Quickly spin up temporary Database servers for tests.

=head1 DESCRIPTION

This is a test library build around DBIx::QuickDB.

=head1 SYNOPSIS

    use Test2::V0 -target => DBIx::QuickDB::Driver::PostgreSQL;
    use Test2::Tools::QuickDB;

    skipall_unless_can_db('PostgreSQL');

    my $db = get_db db => {driver => 'PostgreSQL', load_sql => 't/schema/postgresql.sql'};

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
