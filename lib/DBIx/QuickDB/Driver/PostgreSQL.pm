package DBIx::QuickDB::Driver::PostgreSQL;
use strict;
use warnings;

our $VERSION = '0.000001';

use Carp qw/confess/;
use IPC::Cmd qw/can_run/;
use Time::HiRes qw/sleep/;
use POSIX ":sys_wait_h";

use parent 'DBIx::QuickDB::Driver';

use DBIx::QuickDB::Util::HashBase qw{
    -data_dir
    -pid
    -log_file

    -initdb -createdb -postgres -psql

    -config
};

my ($INITDB, $CREATEDB, $POSTGRES, $PSQL, $DBDPG);

BEGIN {
    local $@;

    $INITDB   = can_run('initdb');
    $CREATEDB = can_run('createdb');
    $POSTGRES = can_run('postgres');
    $PSQL     = can_run('psql');
    $DBDPG    = eval { require DBD::Pg; 'DBD::Pg'};
}

sub _default_paths {
    return (
        initdb   => $INITDB,
        createdb => $CREATEDB,
        postgres => $POSTGRES,
        psql     => $PSQL,
    );
}

sub _default_config {
    my $self = shift;

    return (
        datestyle                  => "'iso, mdy'",
        default_text_search_config => "'pg_catalog.english'",
        dynamic_shared_memory_type => "posix",
        lc_messages                => "'en_US.UTF-8'",
        lc_monetary                => "'en_US.UTF-8'",
        lc_numeric                 => "'en_US.UTF-8'",
        lc_time                    => "'en_US.UTF-8'",
        listen_addresses           => "''",
        max_connections            => "100",
        shared_buffers             => "128MB",
        unix_socket_directories    => "'$self->{+DIR}'",

        #log_timezone               => "'US/Pacific'",
        #timezone                   => "'US/Pacific'",
    );
}

sub viable {
    my $this = shift;
    my ($spec) = @_;

    my %check = (ref($this) ? %$this : (), $this->_default_paths, %$spec);

    my @bad;

    push @bad => "'DBD::Pg' module could not be loaded, needed for everything" unless $DBDPG;

    if ($spec->{bootstrap}) {
        push @bad => "'initdb' command is missing, needed for bootstrap"   unless $check{initdb}   && -x $check{initdb};
        push @bad => "'createdb' command is missing, needed for bootstrap" unless $check{createdb} && -x $check{createdb};
    }

    if ($spec->{autostart}) {
        push @bad => "'postgres' command is missing, needed for autostart" unless $check{postgres} && -x $check{postgres};
    }

    if ($spec->{load_sql}) {
        push @bad => "'psql' command is missing, needed for load_sql" unless $check{psql} && -x $check{psql};
    }

    return (1, undef) unless @bad;
    return (0, join "\n" => @bad);
}

sub init {
    my $self = shift;
    $self->SUPER::init();

    $self->{+DATA_DIR} = $self->{+DIR} . '/data';

    my %defaults = $self->_default_paths;
    $self->{$_} ||= $defaults{$_} for keys %defaults;

    my %cfg_defs = $self->_default_config;
    my $cfg = $self->{+CONFIG} ||= {};

    for my $key (keys %cfg_defs) {
        next if defined $cfg->{$key};
        $cfg->{$key} = $cfg_defs{$key};
    }
}

sub bootstrap {
    my $self = shift;

    my $dir = $self->{+DIR};
    my $db_dir = $self->{+DATA_DIR};
    mkdir($db_dir) or die "Could not create data dir: $!";
    $self->run_command([$self->{+INITDB}, '-D', $db_dir]);

    open(my $cf, '>', "$db_dir/postgresql.conf") or die "Could not open config file: $!";
    for my $key (sort keys %{$self->{+CONFIG}}) {
        my $val = $self->{+CONFIG}->{$key};
        next unless length($val);

        print $cf "$key = $val\n";
    }
    close($cf);

    $self->start;

    for my $try ( 1 .. 5 ) {
        my $ok = eval { $self->run_command([$self->{+CREATEDB}, '-h', $dir, 'quickdb']); 1 };
        my $err = $@;
        last if $ok;
        die $@ if $try == 5;
        sleep 1;
    }

    $self->stop unless $self->{+AUTOSTART};

    return;
}

sub start {
    my $self = shift;

    my $dir = $self->{+DIR};
    my $db_dir = $self->{+DATA_DIR};

    return if $self->{+PID} || -S "$dir/.s.PGSQL.5432";

    my ($pid, $log_file) = $self->run_command([$self->{+POSTGRES}, '-D', $db_dir], {no_wait => 1});

    my $start = time;
    until (-S "$dir/.s.PGSQL.5432") {
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

sub load_sql {
    my $self = shift;
    my ($file) = @_;

    my $dir = $self->{+DIR};

    $self->run_command([
        $self->{+PSQL},
        '-h' => $dir,
        '-v' => 'ON_ERROR_STOP=1',
        '-f' => $file,
        'quickdb'
    ]);
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
                $msg = "\nCould not open postgres log file '$lf': $!";
            }
        }
        warn "PostgreSQL exited badly ($exit)$msg";
    }

    delete $self->{+LOG_FILE};
    delete $self->{+PID};
}

sub connect_string {
    my $self = shift;
    my ($db_name) = @_;
    $db_name ||= 'quickdb';

    my $dir = $self->{+DIR};

    return "dbi:Pg:dbname=$db_name;host=$dir"
}

sub connect {
    my $self = shift;
    my ($db_name, %params) = @_;

    %params = (AutoCommit => 1) unless @_ > 1;

    my $cstring = $self->connect_string($db_name);

    require DBI;
    return DBI->connect($cstring, "", "", \%params);
}

sub shell {
    my $self = shift;
    my ($db_name) = @_;
    $db_name ||= 'quickdb';

    system($self->{+PSQL}, $db_name, '-h' => $self->{+DIR});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

DBIx::QuickDB::Driver::PostgreSQL - PostgreSQL driver for DBIx::QuickDB.

=head1 DESCRIPTION

PostgreSQL driver for L<DBIx::QuickDB>.

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
