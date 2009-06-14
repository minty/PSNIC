package PSNIC::Controller::Pod;

use strict;
use warnings;
use parent 'Catalyst::Controller';

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # XXX The default behaviour should be set higher up
    $c->stash->{template} = 'pod.tt';

    # XXX What about when we have no query_keywords
    # XXX What about if we match multiple modules?
    $c->stash->{module} = $c->model('DB::InstalledModule')->search({
        name => $c->request->query_keywords,
    },{});
}

1;
