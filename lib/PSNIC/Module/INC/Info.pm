package PSNIC::Module::INC::Info;

use warnings;
use strict;

use Module::Build::ModuleInfo;
use Moose;
no  lib '.';

has "$_\_path" => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
) for qw<full inc>;

has is_core => (
    is  => 'rw',
    isa => 'Bool',
);

sub relative_path {
    my ($self) = @_;
    my $base = $self->inc_path;
    return $self->full_path =~ m{\A $base / (.*) \z}x ? $1 : undef;
}

sub version {
    my ($self) = @_;
    return Module::Build::ModuleInfo->new_from_file($self->full_path)->version;
}

sub name {
    my ($self) = @_;
    (my $name = $self->relative_path) =~ s{/}{::}g;
    return $name =~ m{\A (.*) \. (pm|pod) \z}x ? $1 : $name;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
