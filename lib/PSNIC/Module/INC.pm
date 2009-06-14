package PSNIC::Module::INC;

# derived from pminst by tchrist@perl.com
# see http://london.pm.org/pipermail/london.pm/Week-of-Mon-20090323/016889.html
# and http://london.pm.org/pipermail/london.pm/Week-of-Mon-20090330/016896.html
# File::Find::Rule->file()->name('*.pm')->in(@INC) rejected because we need the
# relative path name to calculate the actual module name.
# Module::Util qw<find_in_namespace> rejected because we can't get the full
# path from /
# pminst rejected because we'd need to shell out.
# Module::INC gives us the info we need via the api we want.

use File::Find;
use Module::CoreList;
use PSNIC::Module::INC::Info;
use Moose;
no  lib '.';

sub BUILD {
    my ($self) = @_;
    (my $perl_version = $]) =~ s/0*\z//; # grr
    $self->{core} = $Module::CoreList::version{$perl_version};
}

sub list {
    my ($self) = @_;

    my @matches;
    find(
        sub {
            # $_                 =  foo.txt
            # $File::Find::name  =  /var/tmp/foo.txt
            # $File::Find::dir   =  /var/tmp/

            # XXX What about .pod files?
            return if $_ !~ m{\. (pm|pod) \z}x;

            # Don't go down site_perl etc too early
            # XXX why not?
            if (-d && m/^[a-z]/) {
                $File::Find::prune = 1;
                return;
            }

            # provided we didn't pass find() the 'follow' or 'follow_fast'
            # options $File::Find::topdir is the original starting dir
            # passed to find()
            my $module = PSNIC::Module::INC::Info->new(
                full_path => $File::Find::name,
                inc_path  => $File::Find::topdir,
            );
            $module->is_core( exists $self->{core}{ $module->name } );
            push @matches, $module;
        },
        grep { -d } @INC
    );
    return @matches;
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
