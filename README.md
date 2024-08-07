# NAME

DBIx::QuickDB - Quickly start a db server.

# DESCRIPTION

This library makes it easy to spin up a temporary database server for any
supported driver. PostgreSQL, MySQL and SQLite are the initially supported
drivers.

# SYNOPSIS

These are nearly identical, creating databases that can be retrieved by name
globally. The difference is that the first will build them at compile-time and
will provide constants for accessing them. The second will build them at
run-time and you have to store them in variables.

## DB CONSTANTS

    use DBIx::QuickDB MYSQL_DB => {driver => 'MySQL'};
    use DBIx::QuickDB PSQL_DB  => {driver => 'PostgreSQL'};

    my $m_dbh = MYSQL_DB->connect;
    my $p_dbh = PSQL_DB->connect;

    ...

## DB ON THE FLY

    use DBIx::QuickDB;

    my $msql = DBIx::QuickDB->build_db(mysql_db => {driver => 'MySQL'});
    my $psql = DBIx::QuickDB->build_db(pg_db => {driver => 'PostgreSQL'});

    my $m_dbh = $msql->connect;
    my $p_dbh = $psql->connect;

    ...

## ENV VARS

- QDB\_TMPDIR

    Set this env var if you want QDB to use a temp dir other than the default.

- DB\_VERBOSE

    Set this env var to get STDOUT from the database server.

# METHODS

- $db = DBIx::QuickDB->build\_db();
- $db = DBIx::QuickDB->build\_db($name);
- $db = DBIx::QuickDB->build\_db(\\%spec);
- $db = DBIx::QuickDB->build\_db($name => \\%spec);

    If a `$name` is provided then the database will be named. If the named
    database has already been created it will be returned ignoring any other
    arguments. If the named db does not yet exist it will be created.

    If a `%spec` hashref is provided it will be used to construct the database.
    See ["SPEC HASH"](#spec-hash) for what is supported in `%spec`.

- ($bool, $fqd, $why ) = DBIx::QuickDB->check\_driver($driver => \\%spec);

    The first argument must be a driver name. The name may be shorthand IE
    `"PostgreSQL"` or it can be a fully qualified module name like
    `"DBIx::QuickDB::Driver::PostgreSQL"`.

    The second argument is option, but when present must be a spec hash. See
    ["SPEC HASH"](#spec-hash) for what is supported in `%spec`.

    This method returns a sequence of 3 values:

    - $bool

        True if the driver is viable for the specifications. False if the driver cannot
        be used.

    - $fqd

        The full package name for the driver.

    - $why

        If `$bool` is false then this will have an explanation for why the driver is
        not viable.

# SPEC HASH

Here is an overview of all options allowed:

    my %spec = (
        autostart => BOOL,
        autostop  => BOOL,
        bootstrap => BOOL,
        cleanup   => BOOL,
        dir       => PATH,
        driver    => DRIVER_NAME,
        drivers   => ARRAYREF,
        load_sql  => FILE_OR_HASH,
        nocache   => BOOL,
    );

- autostart => BOOL

    Defaults to true. When true the DB server will be started automatically. If
    this is false then you will need to call `$DB->start` yourself.

- autostop  => BOOL

    Defaults to be the same as the `'autostart'` key.

    When true, the server will automatically be stopped when the program ends.

- bootstrap => BOOL

    This defaults to true unless the `'dir'` key is also provided, in which case
    it will default to false.

    When true this will cause the database to be bootstrapped into existance in the
    specified (or generated) directory (IE the `'dir'` key).

- cleanup => BOOL

    This defaults to true unless the `'dir'` key is also provided, in which case
    it will default to false.

    When true the databse directory will be completely deleted when the program is
    finished. **DO NOT USE THIS ON ANY IMPORTANT DATABASES**.

- dir => PATH

    Use this key to point at an existing database directory. If not provided a
    tempdir will be generated.

- driver => DRIVER\_NAME

    This key lets you specify a driver to use. This must be a string, and can
    either be the shorthand name IE 'PostgreSQL', or the full name IE
    'DBIx::QuickDB::Driver::PostgreSQL'.

    If this key is present then no other drivers will be tried or used.

    If this key is missing then the `'drivers'` key will be used. If both keys are
    empty than any installed driver may be used.

- drivers => ARRAYREF

    If you are only a little picky about driver choice then you can use this to
    list several drivers that are acceptible, the first one that works will be
    used.

    This key is ignored if the `'driver'` key is specified. If both keys are empty
    than any installed driver may be used.

- load\_sql => FILE\_OR\_HASH

    This can be a path to an SQL file to load, an arrayref of several files to
    load, or a structure with driver specific files to load.

        load_sql => '/path/to/my/schema.sql'

        load_sql => ['schema1.sql', 'schema2.sql']

        load_sql => {
            PostgreSQL => 'path/to/postgre.sql',
            MySQL      => 'path/to/my.sql',
            SQLite     => ['sqlite1.sql', 'sqlite2.sql'],
        }

- nocache => BOOL

    Defaults to false. When set to true the database will not be available globally
    by the name passed into `build_db()`.

# SOURCE

The source code repository for DBIx-QuickDB can be found at
`https://github.com/exodist/DBIx-QuickDB/`.

# MAINTAINERS

- Chad Granum <exodist@cpan.org>

# AUTHORS

- Chad Granum <exodist@cpan.org>

# COPYRIGHT

Copyright 2020 Chad Granum <exodist7@gmail.com>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://dev.perl.org/licenses/`
