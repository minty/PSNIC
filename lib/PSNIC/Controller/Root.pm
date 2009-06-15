package PSNIC::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use FindBin;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

PSNIC::Controller::Root - Root Controller for PSNIC

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

# Just load the static index page
# XXX There must be a better way to do this?
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{path} = "$FindBin::Bin/../root/index.tt";
}
sub help :Local :Args(0) { }
sub alternatives :Local :Args(0) { }

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut 

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

SysMon C<sysmonblog@googlemail.com>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
