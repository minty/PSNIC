package PSNIC::Controller::Dialog;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use List::MoreUtils qw<any>;
use Data::JavaScript::Anon;

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $request     = $c->request;
    my $response    = $c->response;
    my $rs          = $c->model('DB::Dialog');
    my %valid_attrs = map { $_ => 1 }
                        qw<session x y z width height top lft pod title>;

    # XXX Form validation!
    # http://search.cpan.org/perldoc?Data::FormValidator
    if ($request->method eq 'POST') {
        my $params = $request->body_params;
        $params->{$_} = trim($params->{$_}) for qw<title pod>;
        $response->status(400)
            if any { !defined $params->{$_} } qw<action session z>;
        my (%data, $dialog);
        my $session_id = $params->{session};
        my $s_rs = $c->model('DB::Session');
        $c->model('DB')->schema->txn_do(sub{

            # Ensure we have a (active) session for the dialog
            $s_rs->search({ active => 1 })->update({ active => 0 });
            my $session = $s_rs->find_or_create({ session => $session_id });
            $session->update({ active => 1 });

            $dialog = $rs->find_or_create({
                session => $session_id,
                z       => $params->{z},
            });
        });
        return if !$dialog;
        my $action = $params->{action};
        if ($action eq 'delete') {
            $dialog->delete;
            $s_rs->find($session_id)->delete
                if !$rs->search({ session => $session_id })->count;
        }
        elsif ($action eq 'save') {
            $dialog->update({
                map  { $_ => $params->{$_} }          # map into required struct
                grep { $valid_attrs{ $_ } }           # Only known attributes
                grep { $_ !~ /\Aaction|session|z\z/ } # Exclude action/session/z
                keys %$params                         # All submitted fields
            });
        }
        else { $response->status(404) }
        $response->body(Data::JavaScript::Anon->anon_dump(\%data));
    }
    elsif ($request->method eq 'GET') {
        my $params = $request->query_params;
        $response->status(400)
            if !defined $params->{session};
        my %constraints = map { $_ => $params->{$_} }
                          grep { defined $params->{$_} }
                          qw<session z>;
        my @dialogs;
        for my $dialog ($rs->search(\%constraints, { order_by => 'z' })->all) {
            push @dialogs, {
                map { $_ => $dialog->$_() }
                qw<session x y z width height top lft pod title>
            };
        }
        $response->body(Data::JavaScript::Anon->anon_dump(\@dialogs));
    }
    else { $response->status(404) }
}

sub trim {
    my ($string) = @_;
    $string =~ s/\A\s*//;
    $string =~ s/\s*\z//;
    return $string;
}

1;
