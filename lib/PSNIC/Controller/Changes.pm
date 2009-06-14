package PSNIC::Controller::Changes;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use LWP::UserAgent;

# XXX This ain't big or clever, but ya know, jfdi an' all that.
# We need a better way to find what the change log file is called.
sub index :Path :Args(0) {
    my ($self, $c) = @_;

    my $base_uri = join '',
        $c->config->{changes_base_uri},
        $c->request->query_keywords;
    my $ua = LWP::UserAgent->new();

    try($c, $ua, "$base_uri$_") for qw<Changes ChangeLog>;
    $c->response->body('no change log found could be found, sorry');
}

sub try {
    my ($c, $ua, $url) = @_;

    $c->response->redirect($url)
        if $ua->get($url)->is_success;
    return;
}

1;
