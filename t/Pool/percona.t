use Test2::V0;
use Test2::Tools::QuickDB;
use File::Spec;

BEGIN {
    $ENV{PATH}="$ENV{HOME}/dbs/percona8/bin:$ENV{PATH}" if -d "$ENV{HOME}/dbs/percona8/bin";
}

my @ENV_VARS;

# Contaminate the ENV vars to make sure things work even when these are all
# set.
BEGIN {
    @ENV_VARS = qw{
        DBI_USER DBI_PASS DBI_DSN
        LIBMYSQL_ENABLE_CLEARTEXT_PLUGIN LIBMYSQL_PLUGINS
        LIBMYSQL_PLUGIN_DIR MYSQLX_TCP_PORT MYSQLX_UNIX_PORT MYSQL_DEBUG
        MYSQL_GROUP_SUFFIX MYSQL_HISTFILE MYSQL_HISTIGNORE MYSQL_HOME
        MYSQL_HOST MYSQL_OPENSSL_UDF_DH_BITS_THRESHOLD
        MYSQL_OPENSSL_UDF_DSA_BITS_THRESHOLD
        MYSQL_OPENSSL_UDF_RSA_BITS_THRESHOLD MYSQL_PS1 MYSQL_PWD
        MYSQL_SERVER_PREPARE MYSQL_TCP_PORT MYSQL_TEST_LOGIN_FILE
        MYSQL_TEST_TRACE_CRASH MYSQL_TEST_TRACE_DEBUG MYSQL_UNIX_PORT
    };
    $ENV{$_} = 'fake' for @ENV_VARS;
}

skipall_unless_can_db('Percona');

sub DRIVER() { 'Percona' }

my $file = __FILE__;
$file =~ s/percona\.t$/Pool.pm/;
$file = File::Spec->rel2abs($file);
require $file;

done_testing;
