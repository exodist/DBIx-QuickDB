use Test2::V0 -target => DBIx::QuickDB::Driver::SQLite;
use Test2::Tools::QuickDB;

skipall_unless_can_db(driver => 'SQLite');

subtest use_it => sub {
    my $db = get_db db => {driver => 'SQLite', load_sql => [quickdb => 't/schema/sqlite.sql']};
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
    my $db = get_db {driver => 'SQLite', load_sql => [quickdb => 't/schema/sqlite.sql']};
    my $dir = $db->dir;
    my $pid = $db->pid;

    ok(-d $dir, "Can see the db dir");

    $db = undef;
    ok(!-d $dir, "Cleaned up the dir when done");
};

subtest viable => sub {
    my ($v, $why) = $CLASS->viable({sqlite => 'a fake path', load_sql => 1});
    ok(!$v, "Not viable without a valid sqlite3");
};

done_testing;
