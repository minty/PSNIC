package PSNIC::Schema::Module;
use base qw/DBIx::Class/;

# see DBIx::Class::Manual::Intro

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('modules');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'int',
        is_auto_increment => 1,
    },
    distribution => {
        data_type         => 'varchar',
    },
    name => {
        data_type         => 'varchar',
    },
    version => {
        data_type         => 'varchar',
        is_nullable       => 1,
    },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to('distribution', 'PSNIC::Schema::Distribution');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'module_ft_idx',
        fields => [qw<distribution name>],
        type   => 'FULLTEXT',
    );
}

1;
