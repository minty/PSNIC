package PSNIC::Schema::Session;
use base qw/DBIx::Class/;
use DateTime;

# see DBIx::Class::Manual::Intro

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('session');
__PACKAGE__->add_columns(
    session => {
        data_type         => 'int',
        default_value     => 1,
    },
    created_at => {
        data_type         => 'datetime',
    },
    label => {
        data_type         => 'varchar',
        size              => 2048,
        is_nullable       => 1,
    },
    query => {
        data_type         => 'varchar',
        size              => 2048,
        is_nullable       => 1,
    },
    active => {
        data_type         => 'boolean',
        default_value     => 0,
    },
);

__PACKAGE__->set_primary_key(qw<session>);

# Auto populate the 'created_at' column
sub new {
    my ($class, $attrs) = @_;
    $attrs->{created_at} ||= DateTime->now;
    return $class->next::method($attrs);
}

1;
