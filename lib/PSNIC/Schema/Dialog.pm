package PSNIC::Schema::Dialog;
use base qw/DBIx::Class/;
use DateTime;

__PACKAGE__->load_components(qw/PK::Auto InflateColumn::DateTime Core/);
__PACKAGE__->table('dialog');
__PACKAGE__->add_columns(
    session => {
        data_type         => 'int',
        default_value     => 1,
    },
    created_at => {
        data_type         => 'datetime',
    },
    pod => {
        data_type         => 'varchar',
        size              => 2048,
        default_value     => '',
    },
    title => {
        data_type         => 'varchar',
        size              => 2048,
        default_value     => '',
    },
    map {
        $_ => { data_type => 'int', default_value => 0 }
    } qw<x y z width height top lft>
);

__PACKAGE__->set_primary_key(qw<session z>);

# Auto populate the 'created_at' column
sub new {
    my ($class, $attrs) = @_;
    $attrs->{created_at} ||= DateTime->now;
    return $class->next::method($attrs);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'dialog_session_idx',
        fields => ['session'],
    );
}

1;
