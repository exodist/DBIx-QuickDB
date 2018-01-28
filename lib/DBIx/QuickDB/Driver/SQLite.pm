package DBIx::QuickDB::Driver::SQLite;
use strict;
use warnings;

use IPC::Cmd qw/can_run/;

our $VERSION = '0.000004';

use parent 'DBIx::QuickDB::Driver';

use DBIx::QuickDB::Util::HashBase qw{-sqlite};

my ($SQLITE, $DBDSQLITE);

BEGIN {
    local $@;

    $SQLITE = can_run('sqlite3');
    $DBDSQLITE = eval { require DBD::SQLite; 'DBD::SQLite' };
}

sub _default_paths { return (sqlite => $SQLITE) }

sub viable {
    my $this = shift;
    my ($spec) = @_;

    my %check = (ref($this) ? %$this : (), $this->_default_paths, %$spec);

    my @bad;
    push @bad => "'DBD::SQLite' module could not be loaded, needed for everything" unless $DBDSQLITE;

    if ($spec->{load_sql}) {
        push @bad => "'sqlite3' command is missing, needed for load_sql" unless $check{sqlite} && -x $check{sqlite};
    }

    return (1, undef) unless @bad;
    return (0, join "\n" => @bad);
}

sub init {
    my $self = shift;
    $self->SUPER::init();

    my %defaults = $self->_default_paths;
    $self->{$_} ||= $defaults{$_} for keys %defaults;

    return;
}

sub bootstrap { return }
sub start     { return }
sub stop      { return }

sub connect_string {
    my $self = shift;
    my ($db_name) = @_;
    $db_name = 'quickdb' unless defined $db_name;

    my $dir = $self->{+DIR};
    my $path = "$dir/$db_name";

    require DBD::SQLite;
    return "dbi:SQLite:dbname=$path";
}

sub load_sql {
    my $self = shift;
    my ($db_name, $file) = @_;

    my $dir = $self->{+DIR};
    my $path = "$dir/$db_name";

    $self->run_command(
        [
            $self->{+SQLITE},
            '-bail',
            $path
        ],
        {stdin => $file},
    );
}

sub shell_command {
    my $self = shift;
    my ($db_name) = @_;

    my $dir = $self->{+DIR};
    my $path = "$dir/$db_name";

    return ($self->{+SQLITE}, $path);
}


1;
