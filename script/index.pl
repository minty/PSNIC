#!/usr/bin/perl

use warnings;
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use List::MoreUtils qw<none any all>;
use DateTime;
use App::Cache;
use Getopt::Long;
use Pod::Usage;

use Parse::CPAN::Cached;

use PSNIC::Stats::Counter;
use PSNIC::Carp::Info qw<configure_info info>;
use PSNIC::Schema;
use PSNIC::Module::INC;
use PSNIC::Config::Local qw<get_conf>;
use PSNIC::Module::Indexer;

no lib "$FindBin::Bin/../lib";

GetOptions(
    \my %opts,
    'cache_ttl:i',
    'verbose|v',
    'authors|a',        # (re)index all cpan authors
    'distributions|d',  # (re)index all cpan distributions
    'installed|i',      # (re)index all installed
    'module|m=s',       # A specific module
    'dir=s',            # A specific directory
    'prefix',           # Use --module or --directory as a prefix filter
    'delete-first|f',   # Delete installed modules & force reindex
    'reset-db',         # Drop and recreate all tables.  All data is lost.
    'help|?',
);
usage() if $opts{help};
usage('module|dir|prefix invalid with authors|distributions|installed')
    if (any { $opts{$_} } qw<authors distributions installed>)
    && (any { $opts{$_} } qw<module dir prefix>);
usage('module and dir mutually exclusive')
    if all { $opts{$_} } qw<module dir>;
usage('prefix requires either module or dir')
    if $opts{prefix}
    && none { $opts{$_} } qw<module dir>;
usage('reset-db cannot be used with indexing options')
    if $opts{'reset-db'}
    && any { $opts{$_} } qw<authors distributions installed module dir prefix>;
warn '--delete-first redundant with authors|distributions|installed'
    if $opts{'delete-first'}
    && any { $opts{$_} } qw<authors distributions installed>;

configure_info( verbose => 1, show_mem => 1 ) if $opts{verbose};

my %parser_args;
$parser_args{cache} = App::Cache->new({ ttl => $opts{cache_ttl} })
    if $opts{cache_ttl};
$parser_args{info} = sub { info @_ };

my $parsers       = Parse::CPAN::Cached->new(%parser_args);
my $distributions = $parsers->parse_cpan('packages');
my $db            = PSNIC::Schema->db_connect;
if ($opts{'reset-db'}) {
    warn "Dropping and re-creating all db tables.  All data will be lost\n";
    $db->deploy({ add_drop_table => 1});
    warn "Done\n";
    exit;
}
my $indexer = PSNIC::Module::Indexer->new(
    db            => $db,
    distributions => $distributions,
    delete_first  => $opts{'delete-first'},
);

load_cpan_authors($db, $parsers->parse_cpan('authors'))
    if $opts{authors};
load_cpan_distributions($db, $distributions)
    if $opts{distributions};
index_all_installed_modules($indexer)
    if $opts{installed};
index_some_installed_modules($indexer, %opts)
    if any { defined $opts{$_} } qw<module dir>;

################################################################################

# XXX handle more than subsets of @INC
sub index_some_installed_modules {
    my ($indexer, %opts) = @_;

    info 'indexing a subset of installed modules';
    my @subset = grep {
        $opts{module} && $opts{prefix} ? $_->name =~ /\A$opts{module}/
      : $opts{module}                  ? $_->name eq $opts{module}
      : $opts{dir} && $opts{prefix}    ? $_->full_path =~ /\A$opts{dir}/
      : $opts{dir}                     ? $_->full_path eq $opts{dir}
      :                                  1;
    } PSNIC::Module::INC->new->list;
    _index_modules($indexer, @subset);
}

sub index_all_installed_modules {
    my ($indexer) = @_;

    info 'indexing all installed modules';
    drop_then_deploy($db, qw<InstalledModule ModuleSubroutine ModulePodHeading>);
    _index_modules($indexer, Module::INC->new->list);
}

sub _index_modules {
    my ($indexer, @modules) = @_;

    my $counter           = PSNIC::Stats::Counter->new(
        tasks        => scalar @modules,
        report_every => 5,
        info         => sub { info @_ },
    );

    info 'Indexing installed modules';
    for my $module (@modules) {
        $indexer->index_module($module);
        $counter->tick;
    }
}

################################################################################

sub load_cpan_authors {
    my ($db, $authors) = @_;

    info 'Loading authors from minicpan';
    drop_then_deploy($db, 'Author');
    $db->resultset('Author')->update_or_create({
        pauseid => $_->pauseid,
        name    => $_->name,
    }) for $authors->authors;
}

sub load_cpan_distributions {
    my ($db, $distributions) = @_;

    info 'Loading meta data about distributions from minicpan';
    drop_then_deploy($db, 'Distribution', 'Module');
    # XXX Stats::Counter should be extended to report every N seconds
    my $counter           = PSNIC::Stats::Counter->new(
        tasks        => scalar $distributions->distributions,
        report_every => 200,
        info         => sub { info @_ },
    );
    for my $dist ($distributions->distributions) {

        $counter->tick;
        my @modules = $dist->contains;
        my $name    = $dist->dist          ? $dist->dist
                    : scalar @modules == 1 ? $modules[0]->package
                    :                        undef;

        next if any { !defined $_ } $name, $dist->cpanid, $dist->prefix;

        $db->resultset('Distribution')->create({
            pauseid => $dist->cpanid,
            name    => $name,
            prefix  => $dist->prefix,
            version => $dist->version,
        });

        for (@modules) {
            $db->resultset('Module')->create({
                distribution => $name,
                name         => $_->package,
                version      => $_->version,
            });
        }

    }
}

sub drop_then_deploy {
    my ($db, @tables) = @_;

    $db->deploy({
        add_drop_table => 1,
        sources        => \@tables,
    });
}

sub usage {
    my ($msg) = @_;
    my %params = $msg ? (message => $msg) : ();
    $params{exitval} = 1;
    pod2usage(%params);
}

=head1 NAME

indexer

=head1 SYNOPSIS

this is the indexer pod.  Put the usage information here for po2usage.

=head1 DESCRIPTION

Some description here

=head1 AUTHOR

SysMon C<sysmonblog@googlemail.com>

=head1 COPYRIGHT

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__;
