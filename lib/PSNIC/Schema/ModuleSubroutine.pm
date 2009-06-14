package PSNIC::Schema::ModuleSubroutine;
use base qw/DBIx::Class/;

# see DBIx::Class::Manual::Intro

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('module_subroutine');
__PACKAGE__->add_columns(
    module_id  => { data_type => 'int' },
    subroutine => { data_type => 'text' },
);

__PACKAGE__->belongs_to(module => 'PSNIC::Schema::InstalledModule', 'module_id');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'module_subroutine_ft_idx',
        fields => [qw<subroutine>],
        type   => 'FULLTEXT',
    );
}

1;
