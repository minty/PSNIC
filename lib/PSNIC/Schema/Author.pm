package PSNIC::Schema::Author;
use base qw/DBIx::Class/;

# see DBIx::Class::Manual::Intro

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('authors');
__PACKAGE__->add_columns(
    pauseid => {
        data_type         => 'varchar',
    },
    name => {
        data_type         => 'varchar',
        is_nullable       => 1,
    },
);

__PACKAGE__->set_primary_key('pauseid');
__PACKAGE__->has_many('distributions', 'PSNIC::Schema::Distribution', 'pauseid');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'author_ft_idx',
        fields => [qw<pauseid name>],
        type   => 'FULLTEXT',
    );
}

1;
