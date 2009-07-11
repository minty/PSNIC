package PSNIC::Model::Debugger;

use base qw<DBIx::Class::Storage::Statistics>;

sub query_start {
    my ($self, $sql_query, @params) = @_;

    # There will be fringe cases that break this
    # but it's a simple easy first start
    while (my $param = shift @params) {
        $sql_query =~ s/ \? / $param /;
    }
    $sql_query =~ s/(FROM|WHERE|ORDER BY|LIMIT)/\n$1/g;
    warn "$sql_query\n\n";
}

1;
