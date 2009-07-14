package PSNIC::Schema::InstalledModule;
use base qw/DBIx::Class/;

use DateTime;

# see DBIx::Class::Manual::Intro

my @text_idx_cols = qw<code pod comment sub_names pod_html pod_name pod_description>;
my %text_cols_def = map {
    $_ => { data_type => 'text', is_nullable => 1 }
} @text_idx_cols;

__PACKAGE__->load_components(qw/PK::Auto InflateColumn::DateTime Core/);
__PACKAGE__->table('installed_modules');
__PACKAGE__->add_columns(
    id            => { data_type => 'int',     is_auto_increment => 1 },
    distribution  => { data_type => 'varchar', is_nullable       => 1 },
    name          => { data_type => 'varchar'                         },
    version       => { data_type => 'varchar', is_nullable       => 1 },
    installed_at  => { data_type => 'text'                            },
    last_modified => { data_type => 'datetime'                        },
    %text_cols_def,
);

__PACKAGE__->set_primary_key('id');
#__PACKAGE__->belongs_to('distributions', 'PSNIC::Schema::Distribution',
#    { 'foreign.name' => 'self.distribution' });
__PACKAGE__->has_many('sub_names', 'PSNIC::Schema::ModuleSubroutine', 'module_id');
__PACKAGE__->has_many('pod_headings', 'PSNIC::Schema::ModulePodHeading', 'module_id');

sub new {
    my ($class, $attrs) = @_;
    $attrs->{last_modified} ||= DateTime->now;
    return $class->next::method($attrs);
}

# XXX This is quite likely a "bad smell" for our schema design.
# In any event, installed_module.distribution maps to distributions.name
# and the latter isn't a unique key.  This picks the one with the highest
# version, or by pauseid if version doesn't exit.
sub best_guess_distribution {
    my ($self) = @_;

    return undef if !$self->distribution;

    my $dists = $self->result_source->schema
                    ->resultset('Distribution')->search({
                        name => $self->distribution,
                    }, {
                        order_by => 'me.version DESC, me.pauseid',
                    });
    return $dists->count ? $dists->first : undef;
}

sub cpan_equivalent {
    my ($self) = @_;

    return $self->result_source->schema
        ->resultset('Module')->search({
            name => $self->name,
        })->first;
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'dist_name_idx',
        fields => [qw<distribution name>],
    );

    $sqlt_table->add_index(
        name   => $_->[0] . '_ft_idx',
        fields => $_->[1],
        type   => 'FULLTEXT',
    ) for (
        [ installed_module => [qw<distribution name>] ],
        map { [ $_ => $_ ] } @text_idx_cols
    );
}

# XXX There is surely a better way to do this?
sub sub_context {
    my ($self, $query) = @_;
    return $self->base_context("sub $query", $self->code);
}
sub comment_context {
    my ($self, $query) = @_;
    return $self->base_context($query, $self->comment);
}
sub code_context {
    my ($self, $query) = @_;
    return $self->base_context($query, $self->code);
}
sub pod_context {
    my ($self, $query) = @_;
    return $self->base_context($query, $self->pod);
}
sub base_context {
    my ($self, $query, $data) = @_;

    my @snippet;
    my %seen;

    # First find all the lines that match
    my @line = split /\n/, $data;
    for (my $i = 0; $i < @line; $i++) {
        next if $line[$i] !~ /$query/i;
        $seen{$i} = $line[$i];
    }

    # Now add a line before/after, avoiding duplicate lines
    for my $line_num (sort { $a <=> $b } keys %seen) {
        my @match;
        push @match, line_hash( \@line, $line_num - 1, 'before' )
            if $line_num > 0
            && !$seen{ $line_num - 1 };
        push @match, line_hash( \@line, $line_num, 'match' );
        push @match, line_hash( \@line, $line_num + 1, 'after' )
            if $line_num < (@line - 1)
            && !$seen{ $line_num + 1 };
        push @snippet, \@match;
        $seen{$_} = 1 for ($line_num - 1, $line_num + 1);
    }

    return \@snippet;
}

sub line_hash {
    my ($line, $num, $type) = @_;
    return {
        type => $type,
        line => $line->[ $num ],
        num  => $num,
    };
}

1;
