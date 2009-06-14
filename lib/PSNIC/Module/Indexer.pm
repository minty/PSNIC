package PSNIC::Module::Indexer;

use Moose;
use PSNIC::Module::Parser;
use List::MoreUtils qw<any>;

has db => (
    is       => 'rw',
    isa      => 'Object',
    required => 1,
);
has distributions => (
    is       => 'rw',
    isa      => 'Parse::CPAN::Packages',
    required => 1,
);
has delete_first => (
    is       => 'rw',
    isa      => 'Bool',
    default  => 0,
);

# $module should be an instance of Module::INC::Info
# Or an object that supports ->name, full_path and version methods.
sub index_module {
    my ($self, $module) = @_;

    # XXX Here is our problem.  02_packages.txt.gz doesn't contain
    # .pod files.  Grrr.  We can't get a dist for them, so.... ?
    my $distribution = $self->distributions->package($module->name);
    my $dist = $distribution ? $distribution->distribution->dist : undef;

    my $parser = PSNIC::Module::Parser->new(filepath => $module->full_path);
    $parser->parse;

    my $rs = $self->db->resultset('InstalledModule');

    # Do we already know about this module?
    my $matches = $rs->search({
        distribution => $dist,
        name         => $module->name,
    });

    # If distribution, name and version match, we're done.
    return if !$self->delete_first
           && $matches->count
           && (
              !$module->version ||
              any { $_->version eq $module->version } $matches->all
           );

    # Delete all existing data before re-insering the new.
    for my $match ($matches->all) {
        $self->db->resultset("Module$_")->search({
            module_id => $match->id
        })->delete
            for qw<Subroutine PodHeading>;
        $match->delete;
    }

    # Insert the module row
    my %row = (
        distribution    => $dist,
        name            => $module->name,
        version         => $module->version,
        installed_at    => $module->full_path,
        pod_html        => $parser->pod_html,
        pod_name        => $parser->pod_title,
        pod_description => $parser->pod_description,
        pod             => strip($parser->raw_pod),
        comment         => strip($parser->comments),
        code            => strip($parser->code),
        sub_names       => join ' ', @{ $parser->subroutines },
    );
    my $module_rs = $rs->create(\%row);

    # Associate each sub name with the module
    $self->db->resultset('ModuleSubroutine')->create({
        module_id  => $module_rs->id,
        subroutine => $_,
    }) for @{ $parser->subroutines };

    # Associate each pod section heading with the module.
    $self->db->resultset('ModulePodHeading')->create({
        module_id  => $module_rs->id,
        level      => $_->{level},
        label      => $_->{label},
    }) for @{ $parser->pod_headings };
}

# So strip out stuff we cannot use for searching
# XXX We want to apply some tricks here to special chars like %, $
sub strip {
    my ($string) = @_;
    $string =~ s/[^\w]+|\s+/ /g; # non words or whitespace => ' '
    $string =~ s/\A \s*//x;      # strip leading whitespace
    $string =~ s/\s* \z//x;      # strip training whitespace
    return lc $string;
}

1;
