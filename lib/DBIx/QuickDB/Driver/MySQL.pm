package DBIx::QuickDB::Driver::MySQL;
use strict;
use warnings;

our $VERSION = '0.000002';

use Carp qw/confess/;
use IPC::Cmd qw/can_run/;
use Time::HiRes qw/sleep/;
use POSIX ":sys_wait_h";

use parent 'DBIx::QuickDB::Driver';

use DBIx::QuickDB::Util::HashBase qw{
    -data_dir -temp_dir -socket -pid_file -cfg_file
    -pid
    -log_file

    -mysql_install_db -mysqld -mysql

    -config
};

my ($MYSQL_INSTALL_DB, $MYSQLD, $MYSQL, $DBDMYSQL);

BEGIN {
    local $@;

    $MYSQL_INSTALL_DB = can_run('mysql_install_db');
    $MYSQLD           = can_run('mysqld');
    $MYSQL            = can_run('mysql');
    $DBDMYSQL         = eval { require DBD::mysql; 'DBD::mysql' };
}

sub _default_paths {
    return (
        mysql_install_db => $MYSQL_INSTALL_DB,
        mysqld           => $MYSQLD,
        mysql            => $MYSQL,
    );
}

sub _default_config {
    my $self = shift;

    my $dir = $self->dir;
    my $data_dir = $self->data_dir;
    my $temp_dir = $self->temp_dir;
    my $pid_file = $self->pid_file;
    my $socket   = $self->socket;

    return (
        client => {
            'socket' => $socket,
        },

        mysql_safe => {
            'socket' => $socket,
        },

        mysqld => {
            'datadir'  => $data_dir,
            'pid-file' => $pid_file,
            'socket'   => $socket,
            'tmpdir'   => $temp_dir,

            'character-set-server'    => 'utf8',
            'collation-server'        => 'utf8_unicode_ci',
            'default-storage-engine'  => 'InnoDB',
            'innodb_buffer_pool_size' => '20M',
            'key_buffer_size'         => '20M',
            'max_allowed_packet'      => '1M',
            'max_binlog_size'         => '20M',
            'max_connections'         => '100',
            'myisam_sort_buffer_size' => '8M',
            'net_buffer_length'       => '8K',
            'query_cache_limit'       => '1M',
            'query_cache_size'        => '20M',
            'read_buffer_size'        => '256K',
            'read_rnd_buffer_size'    => '512K',
            'server-id'               => '1',
            'skip-external-locking'   => '',
            'skip-networking'         => '',
            'skip_name_resolve'       => '1',
            'sort_buffer_size'        => '512K',
            'table_open_cache'        => '64',
            'thread_cache_size'       => '8',
            'thread_stack'            => '192K',
        },

        mysql => {
            'socket'         => $socket,
            'no-auto-rehash' => '',
        },
    );
}

sub viable {
    my $this = shift;
    my ($spec) = @_;

    my %check = (ref($this) ? %$this : (), $this->_default_paths, %$spec);

    my @bad;

    push @bad => "'DBD::mysql' module could not be loaded, needed for everything" unless $DBDMYSQL;

    if ($spec->{bootstrap}) {
        push @bad => "'mysql_install_db' command is missing, needed for bootstrap" unless $check{mysql_install_db} && -x $check{mysql_install_db};
        push @bad => "'mysqld' command is missing, needed for bootstrap" unless $spec->{autostart} || ($check{mysqld} && -x $check{mysqld});
    }

    if ($spec->{autostart}) {
        push @bad => "'mysqld' command is missing, needed for autostart" unless $check{mysqld} && -x $check{mysqld};
    }

    if ($spec->{load_sql}) {
        push @bad => "'mysql' command is missing, needed for load_sql" unless $check{mysql} && -x $check{mysql};
    }

    return (1, undef) unless @bad;
    return (0, join "\n" => @bad);
}

sub init {
    my $self = shift;
    $self->SUPER::init();

    $self->{+DATA_DIR} = $self->{+DIR} . '/data';
    $self->{+TEMP_DIR} = $self->{+DIR} . '/temp';
    $self->{+PID_FILE} = $self->{+DIR} . '/mysql.pid';
    $self->{+CFG_FILE} = $self->{+DIR} . '/my.cfg';
    $self->{+SOCKET} = $self->{+DIR} . '/mysql.sock';

    my %defaults = $self->_default_paths;
    $self->{$_} ||= $defaults{$_} for keys %defaults;

    my %cfg_defs = $self->_default_config;
    my $cfg = $self->{+CONFIG} ||= {};

    for my $key (keys %cfg_defs) {
        if (defined $cfg->{$key}) {
            my $subdft = $cfg_defs{$key};
            my $subcfg = $cfg->{$key};

            for my $skey (%$subdft) {
                next if defined $subcfg->{$skey};
                $subcfg->{$skey} = $subdft->{$skey};
            }
        }
        else {
            $cfg->{$key} = $cfg_defs{$key};
        }
    }
}

sub connect_string {
    my $self = shift;
    my ($db_name) = @_;
    $db_name ||= 'quickdb';

    my $socket = $self->{+SOCKET};

    return "dbi:mysql:dbname=$db_name;mysql_socket=$socket";
}

sub connect {
    my $self = shift;
    my ($db_name, %params) = @_;

    %params = (AutoCommit => 1) unless @_ > 1;

    my $cstring = $self->connect_string($db_name);

    require DBI;
    return DBI->connect($cstring, "root", "", \%params);
}

sub bootstrap {
    my $self = shift;

    my $data_dir = $self->{+DATA_DIR};
    my $temp_dir = $self->{+TEMP_DIR};

    mkdir($data_dir) or die "Could not create data dir: $!";
    mkdir($temp_dir) or die "Could not create temp dir: $!";

    my $cfg_file = $self->{+CFG_FILE};
    open(my $cfh, '>', $cfg_file) or die "Could not open config file: $!";
    my $conf = $self->{+CONFIG};
    for my $section (sort keys %$conf) {
        my $sconf = $conf->{$section} or next;

        print $cfh "[$section]\n";
        for my $key (sort keys %$sconf) {
            my $val = $sconf->{$key};
            next unless defined $val;

            if (length($val)) {
                print $cfh "$key = $val\n";
            }
            else {
                print $cfh "$key\n";
            }
        }

        print $cfh "\n";
    }
    close($cfh);

    my $base = $self->{+MYSQL_INSTALL_DB};
    $base =~ s{/bin/.*$}{}g;
    $self->run_command([$self->{+MYSQL_INSTALL_DB}, "--defaults-file=$cfg_file", "--basedir=$base"]);

    $self->start;

    for my $try ( 1 .. 5 ) {
        my $dbh = $self->connect('test');
        $dbh->do('CREATE DATABASE quickdb') and last;
        die $dbh->errstr if $try == 5;
        sleep 1;
    }

    $self->stop unless $self->{+AUTOSTART};

    return;
}

sub stop {
    my $self = shift;

    my $pid = $self->{+PID} or return;

    local $?;
    kill('TERM', $pid);
    my $ret = waitpid($pid, 0);
    my $exit = $?;
    die "waitpid returned $ret (expected $pid)" unless $ret == $pid;

    if ($exit) {
        my $msg = "";
        if (my $lf = $self->{+LOG_FILE}) {
            if (open(my $fh, '<', $lf)) {
                $msg = "\n" . join "" => <$fh>;
            }
            else {
                $msg = "\nCould not open mysqld log file '$lf': $!";
            }
        }
        warn "mysqld exited badly ($exit)$msg";
    }

    delete $self->{+LOG_FILE};
    delete $self->{+PID};
}

sub start {
    my $self = shift;

    my $dir = $self->{+DIR};
    my $socket = $self->{+SOCKET};

    return if $self->{+PID} || -S $socket;

    my $cfg_file = $self->{+CFG_FILE};
    my ($pid, $log_file) = $self->run_command([$self->{+MYSQLD}, "--defaults-file=$cfg_file"], {no_wait => 1});

    my $start = time;
    until (-S $socket) {
        my $waited = time - $start;
        my $dump = 0;

        if ($waited > 10) {
            kill('QUIT', $pid);
            waitpid($pid, 0);
            $dump = "Timeout waiting for server:";
        }

        if (waitpid($pid, WNOHANG) == $pid) {
            $dump = "Server failed to start:"
        }

        if ($dump) {
            open(my $fh, '<', $log_file) or warn "Failed to open log: $!";
            my $data = eval { join "" => <$fh> };
            confess "$dump\n$data\nAborting";
        }

        sleep 0.01;
    }

    $self->{+LOG_FILE} = $log_file;
    $self->{+PID}      = $pid;
}

sub shell {
    my $self = shift;
    my ($db_name) = @_;
    $db_name ||= 'quickdb';

    my $cfg_file = $self->{+CFG_FILE};
    system($self->{+MYSQL}, "--defaults-file=$cfg_file", $db_name);
}

sub load_sql {
    my $self = shift;
    my ($file) = @_;

    my $cfg_file = $self->{+CFG_FILE};

    $self->run_command(
        [
            $self->{+MYSQL},
            "--defaults-file=$cfg_file",
            '-u' => 'root',
            'quickdb'
        ],
        {stdin => $file},
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::QuickDB::Driver::MySQL - MySQL driver for DBIx::QuickDB.

=head1 DESCRIPTION

MySQL driver for L<DBIx::QuickDB>.

=head1 SYNOPSIS

See L<DBIx::QuickDB>.

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
