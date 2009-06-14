package PSNIC::Controller::Search;

use strict;
use warnings;
use parent 'Catalyst::Controller';

my $ROWS_PER_PAGE = 100;

# XXX Snippets are the next interesting part.
# If we searched for a sub name, then we should snippet any pod section that matches
#
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # XXX The default behaviour should be set higher up
    $c->stash->{template} = 'search.tt';

    my $r     = $c->request;
    my $query = $r->query_params->{q};
    $c->stash->{pod_page} = 1
        if $r->query_params->{inline};

    my %query = tokenize($query);
    my @conds;
    push @conds, expand_match_against($_ => $query{$_})
        for keys %query;

    # XXX Convert to use search
    # XXX Convert to alternative stash style
    # http://search.cpan.org/~ribasushi/DBIx-Class-0.08102/lib/DBIx/Class/ResultSet.pm#search_literal
    $c->stash->{query} = $query;
    $c->stash->{results} = $c->model('DB::InstalledModule')->search({},{
        page => 1, # Show lots of results & have no pagination
        rows => $ROWS_PER_PAGE,
    })->search_literal(@conds);
}

# XXX this wants to contain the ft index expansions
my %cmds = map { ( "$_:" => 1 ) } qw<mod sub pod code>;

# XXX Wants to handle "phrase matching"
# XXX and negation
sub tokenize {
    my ($query) = @_;

    # strip characters we don't use
    $query =~ s/[^:\s\w]/ /;
    $query =~ s/::/__/g;
    $query =~ s/:([^\s])/: $1/g;
    $query =~ s/__/::/g;
    my @tokens = split /\s+/, lc $query;
    my %query;
    my $cmd = 'query';
    while (my $token = shift @tokens) {
        if ($cmds{$token}) {
            $cmd = $token;
            next;
        }
        push @{ $query{$cmd} }, $token;
        $cmd = 'query';
    }
    return %query;
}

sub expand_match_against {
    my ($mode, $terms) = @_;

    my $query = join ' ', @$terms;
    $query =~ s/:/ /g;
    $query =~ s/ +/ /g;

    # XXX We want a ft index that spans everything for the 'query' mode.
    my @cols = $mode eq 'sub:'  ? 'sub_names'
             : $mode eq 'mod:'  ? qw<distribution name>
             : $mode eq 'query' ? 'pod'
             : $mode eq 'code'  ? 'code'
             :                   ();
    die "unknown mode '$mode'" if !@cols;

    my $cols = join ', ', @cols;
    return qq[MATCH ($cols) AGAINST ( ? )], $query;
}

1;
