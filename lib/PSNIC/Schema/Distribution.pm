package PSNIC::Schema::Distribution;
use base qw/DBIx::Class/;

# see DBIx::Class::Manual::Intro

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('distributions');
__PACKAGE__->add_columns(
    pauseid => {
        data_type         => 'varchar',
    },
    name => {
        data_type         => 'varchar',
    },
    prefix => {
        data_type         => 'varchar',
    },
    version => {
        data_type         => 'varchar',
        is_nullable       => 1,
    },
);

__PACKAGE__->set_primary_key('prefix');
__PACKAGE__->belongs_to('author', 'PSNIC::Schema::Author', 'pauseid');
__PACKAGE__->has_many('modules', 'PSNIC::Schema::Module', 'name');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'distribution_ft_idx',
        fields => [qw<name>],
        type   => 'FULLTEXT',
    );
}

1;
