package DBIx::QuickDB::Driver;
use strict;
use warnings;

our $VERSION = '0.000004';

use Carp qw/croak confess/;
use File::Path qw/remove_tree/;
use POSIX ":sys_wait_h";
use Scalar::Util qw/blessed/;
use Time::HiRes qw/sleep/;

use DBIx::QuickDB::Util::HashBase qw{
    -pid -root_pid -log_file
    -dir
    -_cleanup
    -autostop -autostart
    -verbose
    -log_id
    -username
    -password
};

sub viable { (0, "socket() is not implemented for the " . $_[0]->name . " driver") }

sub socket         { confess "socket() is not implemented for the " . $_[0]->name . " driver" }
sub load_sql       { confess "load_sql() is not implemented for the " . $_[0]->name . " driver" }
sub bootstrap      { confess "bootstrap() is not implemented for the " . $_[0]->name . " driver" }
sub connect_string { confess "connect_string() is not implemented for the " . $_[0]->name . " driver" }
sub start_command  { confess "start_command() is not implemented for the " . $_[0]->name . " driver" }
sub shell_command  { confess "shell_command() is not implemented for the " . $_[0]->name . " driver" }

sub name {
    my $in = shift;
    my $type = blessed($in) || $in;

    $in =~ s/^DBIx::QuickDB::Driver:://;

    return $in;
}

sub init {
    my $self = shift;

    confess "'dir' is a required attribute" unless $self->{+DIR};

    $self->{+ROOT_PID} = $$;
    $self->{+_CLEANUP} = delete $self->{cleanup};

    $self->{+USERNAME} = '' unless defined $self->{+USERNAME};
    $self->{+PASSWORD} = '' unless defined $self->{+PASSWORD};

    return;
}

sub run_command {
    my $self = shift;
    my ($cmd, $params) = @_;
    my $pid = fork();
    croak "Could not fork" unless defined $pid;

    my $no_log = $self->{+VERBOSE} || $params->{no_log} || $ENV{DB_VERBOSE};
    my $log_file = $no_log ? undef : $self->{+DIR} . "/cmd-log-" . $self->{+LOG_ID}++;

    if ($pid) {
        return ($pid, $log_file) if $params->{no_wait};
        local $?;
        my $ret = waitpid($pid, 0);
        my $exit = $?;
        die "waitpid returned $ret" unless $ret == $pid;

        return unless $exit;

        my $log = "";
        unless ($no_log) {
            open(my $fh, '<', $log_file) or warn "Failed to open log: $!";
            $log = eval { join "" => <$fh> };
        }
        croak "Failed to run command '" . join(' ' => @$cmd) . "' ($exit)\n$log";
    }

    unless ($no_log) {
        open(my $log, '>', $log_file) or die "Could not open log file: $!";
        close(STDOUT);
        open(STDOUT, '>&', $log);
        close(STDERR);
        open(STDERR, '>&', $log);
    }

    if (my $file = $params->{stdin}) {
        close(STDIN);
        open(STDIN, '<', $file) or die "Could not open new STDIN: $!";
    }

    exec(@$cmd);
}

sub cleanup {
    my $self = shift;
    remove_tree($self->{+DIR}, {safe => 1});
    return;
}

sub connect {
    my $self = shift;
    my ($db_name, %params) = @_;

    %params = (AutoCommit => 1) unless @_ > 1;

    my $cstring = $self->connect_string($db_name);

    require DBI;
    return DBI->connect($cstring, $self->username, $self->password, \%params);
}

sub start {
    my $self = shift;

    my $dir = $self->{+DIR};
    my $socket = $self->socket;

    return if $self->{+PID} || -S $socket;

    my ($pid, $log_file) = $self->run_command([$self->start_command], {no_wait => 1});

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

sub stop {
    my $self = shift;

    my $pid = $self->{+PID} or return;

    local $?;
    kill('TERM', $pid);
    my $ret = waitpid($pid, 0);
    my $exit = $?;
    die "waitpid returned $ret (expected $pid)" unless $ret == $pid;

    if ($exit) {
        my $name = $self->name;
        my $msg = "";
        if (my $lf = $self->{+LOG_FILE}) {
            if (open(my $fh, '<', $lf)) {
                $msg = "\n" . join "" => <$fh>;
            }
            else {
                $msg = "\nCould not open $name log file '$lf': $!";
            }
        }
        warn "$name exited badly ($exit)$msg";
    }

    delete $self->{+LOG_FILE};
    delete $self->{+PID};
}

sub shell {
    my $self = shift;
    my ($db_name) = @_;
    $db_name = 'quickdb' unless defined $db_name;

    system($self->shell_command($db_name));
}

sub DESTROY {
    my $self = shift;
    return unless $self->{+ROOT_PID} && $self->{+ROOT_PID} == $$;

    $self->stop    if $self->{+AUTOSTOP} || $self->{+_CLEANUP};
    $self->cleanup if $self->{+_CLEANUP};

    return;
}

1;

__END__


=pod

=encoding UTF-8

=head1 NAME

DBIx::QuickDB::Driver - Base class for DBIx::QuickDB drivers.

=head1 DESCRIPTION

Base class for DBIx::QuickDB drivers.

=head1 SYNOPSIS

    package DBIx::QuickDB::Driver::MyDriver;
    use strict;
    use warnings;

    use parent 'DBIx::QuickDB::Driver';

    use DBIx::QuickDB::Util::HashBase qw{ ... };

    sub viable { .. }

    sub init {
        my $self = shift;

        $self->SUPER::init();

        ...
    }

    sub bootstrap { ... }
    sub load_sql  { ... }
    sub connect   { ... }
    sub shell     { ... }
    sub start     { ... }
    sub stop      { ... }

    1;

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
