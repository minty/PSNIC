package PSNIC::Carp::Info;

use strict;
use warnings;

use Exporter qw<import>;
our @EXPORT_OK = qw<info configure_info>;

use DateTime;

my %config;

my $program_name; BEGIN { ($program_name = $0) =~ s[.*/][]; }

sub configure_info {
    %config = @_;
    select((select(STDERR), $| = 1)[0]) if $config{verbose};
}

sub info {
    return if !$config{verbose} && !$config{tell_ps};

    my @timestamp;
    push @timestamp, DateTime->from_epoch(epoch => time, time_zone => 'local')
        ->strftime('%{ymd} %{hms}')
            if !$config{hide_time};
    my $mem_file = '/proc/self/status';
    if ($config{show_mem} && -e $mem_file && open my $fh, '<', $mem_file) {
        local $_;
        while (<$fh>) {
            next if !/^VmSize:\s*(\d+)/;
            push @timestamp, sprintf 'mem:%4dMB', int $1 / 1024;
            last;
        }
    }

    my $timestamp = @timestamp ? "[@timestamp] " : '';

    warn $timestamp, @_, "\n"
        if $config{verbose};

    if ($config{tell_ps}) {
        $timestamp ||= '- ';
        $0 = "$program_name $timestamp@_";
    }
}

1;
