use Test2::V0 -target => DBIx::QuickDB::Driver::PostgreSQL;
use Test2::Tools::QuickDB;

skipall_unless_can_db('PostgreSQL');

subtest use_it => sub {
    my $db = get_db db => {driver => 'PostgreSQL', load_sql => 't/schema/postgresql.sql'};
    isa_ok($db, [$CLASS], "Got a database of the right type");

    is(get_db_or_skipall('db'), exact_ref($db), "Cached the instance by name");

    my $dbh = $db->connect;
    isa_ok($dbh, ['DBI::db'], "Connected");

    ok($dbh->do("INSERT INTO quick_test(test_val) VALUES('foo')"), "Insert success");

    my $sth = $dbh->prepare('SELECT * FROM quick_test WHERE test_val = ?');
    $sth->execute('foo');
    my $all = $sth->fetchall_arrayref({});
    is(
        $all,
        [{test_val => 'foo', test_id => 1}],
        "Got the inserted row"
    );
};

subtest cleanup => sub {
    my $db = get_db {driver => 'PostgreSQL', load_sql => 't/schema/postgresql.sql'};
    my $dir = $db->dir;
    my $pid = $db->pid;

    ok(-d $dir, "Can see the db dir");
    ok(kill(0, $pid), "Can signal the db process (it's alive!)");

    $db = undef;
    ok(!-d $dir, "Cleaned up the dir when done");
    is(kill(0, $pid), 0, "cannot singal pid (It's dead Jim)");
};

subtest viable => sub {
    my ($v, $why) = $CLASS->viable({initdb => 'a fake path', bootstrap => 1});
    ok(!$v, "Not viable without a valid initdb");

    ($v, $why) = $CLASS->viable({createdb => 'a fake path', bootstrap => 1});
    ok(!$v, "Not viable without a valid createdb");

    ($v, $why) = $CLASS->viable({postgres => 'a fake path', autostart => 1});
    ok(!$v, "Not viable without a valid postgres");

    ($v, $why) = $CLASS->viable({psql => 'a fake path', load_sql => 1});
    ok(!$v, "Not viable without a valid psql");
};

done_testing;
