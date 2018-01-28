use Test2::V0 -target => DBIx::QuickDB::Driver::MySQL;
use Test2::Tools::QuickDB;

skipall_unless_can_db('MySQL');

subtest use_it => sub {
    my $db = get_db db => {driver => 'MySQL', load_sql => [quickdb => 't/schema/mysql.sql']};
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
    my $db = get_db {driver => 'MySQL', load_sql => [quickdb => 't/schema/mysql.sql']};
    my $dir = $db->dir;
    my $pid = $db->pid;

    ok(-d $dir, "Can see the db dir");
    ok(kill(0, $pid), "Can signal the db process (it's alive!)");

    $db = undef;
    ok(!-d $dir, "Cleaned up the dir when done");
    is(kill(0, $pid), 0, "cannot singal pid (It's dead Jim)");
};

subtest viable => sub {
    my ($v, $why) = $CLASS->viable({mysql_install_db => 'a fake path', bootstrap => 1});
    ok(!$v, "Not viable without a valid mysql_install_db");

    ($v, $why) = $CLASS->viable({mysqld => 'a fake path', bootstrap => 1});
    ok(!$v, "Not viable without a valid mysqld");

    ($v, $why) = $CLASS->viable({mysqld => 'a fake path', autostart => 1});
    ok(!$v, "Not viable without a valid mysqld");

    ($v, $why) = $CLASS->viable({mysql => 'a fake path', load_sql => 1});
    ok(!$v, "Not viable without a valid mysql");
};

done_testing;
