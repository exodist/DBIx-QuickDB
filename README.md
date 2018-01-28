# NAME

DBIx::QuickDB - Quickly start a db server.

# DESCRIPTION

This library makes it easy to spin up a temporary database server for any
supported driver. PostgreSQL and MySQL are the initially supported drivers.

# SYNOPSIS

    use DBIx::QuickDB MYSQL_DB => {driver => 'MySQL'};
    use DBIx::QuickDB PSQL_DB  => {driver => 'PostgreSQL'};

    my $m_dbh = MYSQL_DB->connect;
    my $p_dbh = PSQL_DB->connect;

    ...

# TODO - MORE DOCS

This is a VERY alpha release, more docs to come, API may change completely.

# SOURCE

The source code repository for DBIx-QuickDB can be found at
`https://github.com/exodist/DBIx-QuickDB/`.

# MAINTAINERS

- Chad Granum <exodist@cpan.org>

# AUTHORS

- Chad Granum <exodist@cpan.org>

# COPYRIGHT

Copyright 2018 Chad Granum <exodist7@gmail.com>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://dev.perl.org/licenses/`
