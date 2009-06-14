package PSNIC::View::TT;

use strict;
use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    WRAPPER            => '_page.tt',
);


=head1 NAME

PSNIC::View::TT - TT View for PSNIC

=head1 DESCRIPTION

TT View for PSNIC.

=head1 AUTHOR

=head1 SEE ALSO

L<PSNIC>

SysMon C<sysmonblog@googlemail.com>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
