package PSNIC::Controller::Session;

#BEGIN { $ENV{DBIC_TRACE} = 1; }

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::JavaScript::Anon;
use List::MoreUtils qw<any>;

# XXX s/dialogs/get/
# Three modes:
# session/list                - all existing sesssion ids & their creation time
# session/dialogs/$session_id - the dialogs within a session
# session/delete              - delete everything about a session
# session/label               - post to set the sessions label
# session/query               - post to set the sessions query

sub label :Local :Args(0) {
    my ($self, $c) = @_;
    $self->set_session_field($c, 'label');
}

sub query :Local :Args(0) {
    my ($self, $c) = @_;
    $self->set_session_field($c, 'query');
}

sub set_session_field {
    my ($self, $c, $field) = @_;

    my $request  = $c->request;
    my $response = $c->response;
    my $rs       = $c->model('DB::Session');
    my $params   = $request->body_params;

    # XXX more/better validation
    $response->status(404) if $request->method ne 'POST';
    $response->status(400)
        if any { !defined $params->{$_} } ('session', $field);
    $response->status(400)
        if $params->{session} !~ /\A \d+ \z/xms
        || length($params->{$field}) > 2048;

    $c->model('DB::Session')->update_or_create({
        session => $params->{session},
        $field  => $params->{$field},
    });
    $response->body('{ status: 1 }');
}

# match exactly /session/list/
sub list :Local :Args(0) {
    my ($self, $c) = @_;

    my @sessions = map { {
        session    => $_->session,
        label      => $_->label,
        created_at => $_->created_at,
        active     => $_->active,
        query      => $_->query,
    } } $c->model('DB::Session')->search({}, {
        order_by => 'created_at',
    })->all;

    $c->response->body(Data::JavaScript::Anon->anon_dump(\@sessions));
}

sub get_optional_label {
    my ($rs, $session) = @_;
    my $row = $rs->find($session);
    return $row ? $row->label : '';
}

# To export the json data
# http://www.mail-archive.com/dbix-class@lists.scsys.co.uk/msg02446.html
# XXX Use RegEx action to get urls like /session/$session_id/dialogs
sub dialogs :Local :Args(1) {
    my ($self, $c, $session_id) = @_;

    my $request  = $c->request;
    my $response = $c->response;
    my $rs       = $c->model('DB::Dialog');
    my $session  = $c->model('DB::Session')->find($session_id);
    if (!$session) {
        $response->body(Data::JavaScript::Anon->anon_dump({}));
        return;
    }

    # XXX This would be better done as an optional parameter
    my $activate = $request->query_keywords || '';
    if ($activate eq 'activate') {
        my $session_rs = $c->model('DB::Session');
        $session_rs->search({ active => 1 })->update({ active => 0 });
        $session->update({ active => 1 });
    }

    # Order by z to retain previous window layering order
    my $dialogs = $rs->search({ session => $session_id }, { order_by => 'z' });

    # XXX How do we find all the available columns?
    # $rs->result_source / ->result_class ?
    my @dialogs;
    for my $dialog ($dialogs->all) {
        push @dialogs, {
            map { $_ => $dialog->get_column($_) }
                qw<session x y z top lft width height pod title>
        };
    }

    $response->body(Data::JavaScript::Anon->anon_dump({
        query   => $session->query,
        dialogs => \@dialogs
    }));
}

1;
