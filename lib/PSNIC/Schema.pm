package PSNIC::Schema;
use base qw/DBIx::Class::Schema/;
use PSNIC::Config::Local qw<get_conf>;

__PACKAGE__->load_classes();

# Used to connect from scripts using
# my $db = PSNIC::Schema->db_connect;
sub db_connect { return shift->connect(@{get_conf('Model::DB.connect_info')}); }

# Ensure all tables are MyISAM.  Required for Full Text Indexes.
sub sqlt_deploy_hook {
    my ($self, $sqlt_schema) = @_;

    $_->extra(mysql_table_type => 'MyIsam')
        for $sqlt_schema->get_tables;
}

1;
