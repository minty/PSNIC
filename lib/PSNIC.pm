package PSNIC;

use strict;
use warnings;

use Catalyst::Runtime '5.70';

# XXX log4perl http://www.perl.com/lpt/a/670
# We'd like $self->logger->DEBUG|ERROR|INFO to work
# We'd like common case shortcuts, like $self->info to also work

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory

use parent qw/Catalyst/;

our $VERSION = '0.01';

# Configure the application. 
#
# Note that settings in psnic.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.

__PACKAGE__->config({
    name             => 'PSNIC',
    changes_base_uri => 'http://cpansearch.perl.org/src/',
});

# Start the application (add -Debug for verbose debugging)
__PACKAGE__->setup(qw/ConfigLoader Static::Simple/);


=head1 NAME

PSNIC - Catalyst based application

=head1 SYNOPSIS

    script/psnic_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<PSNIC::Controller::Root>, L<Catalyst>

=head1 AUTHOR

SysMon C<sysmonblog@googlemail.com>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
