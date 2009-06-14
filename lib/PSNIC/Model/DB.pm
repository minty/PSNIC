package PSNIC::Model::DB;

use base qw/Catalyst::Model::DBIC::Schema/;

__PACKAGE__->config(schema_class => 'PSNIC::Schema');
