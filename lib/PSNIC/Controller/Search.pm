package PSNIC::Controller::Search;

use strict;
use warnings;
use parent 'Catalyst::Controller';

my $ROWS_PER_PAGE = 100;

# XXX Snippets are the next interesting part.
# If we searched for a sub name, then we should snippet any pod section that matches
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my %params           = %{ $c->request->query_params };
    my $query            = $params{q} || $c->response->redirect('/');
    my %query_components = tokenize($query);
    my @conds            = expand_match_against_sql(%query_components);
    my $model            = $c->model('DB::InstalledModule');
    #my $debugger         = PSNIC::Model::Debugger->new();
    #$model->result_source->storage->debugobj($debugger);
    #$model->result_source->storage->debug(1);
    my @results          = $model->search({},{
        page => 1,
        rows => $ROWS_PER_PAGE,
    })->search_literal(@conds)->all;
    #$model->result_source->storage->debug(0);

use Data::Dumper;
warn Dumper \%query_components;

    $c->stash({
        template         => 'search.tt',
        pod_page         => $params{inline} ? 1 : 0,
        query            => $query,
        query_components => \%query_components,
        results          => \@results,
    });
}

# XXX this wants to contain the ft index expansions
my %cmds = map { ( "$_:" => 1 ) } qw<mod sub pod code comment>;

# XXX Wants to handle "phrase matching" and -negation
sub tokenize {
    my ($query) = @_;

    $query = trim($query);

    # strip characters we don't use
    $query =~ s/[^:\s\w]/ /;
    $query =~ s/::/__/g;
    $query =~ s/:([^\s])/: $1/g;
    $query =~ s/__/::/g;
    my @tokens = split /\s+/, lc $query;
    my %query;
    my $cmd = 'query:';
    while (my $token = shift @tokens) {
        if ($cmds{$token}) {
            $cmd = $token;
            next;
        }
        push @{ $query{substr($cmd, 0, -1)} }, $token;
        $cmd = 'query:';
    }
    return %query;
}

sub expand_match_against_sql {
    my (%query) = @_;

    my (@match, @args);
    for my $type (keys %query) {

        my @cols = $type eq 'sub'     ? 'sub_names'
                 : $type eq 'mod'     ? qw<distribution name>
                 : $type eq 'code'    ? 'code'
                 : $type eq 'pod'     ? 'pod'
                 : $type eq 'comment' ? 'comment'
                 : $type eq 'query'   ? qw<distribution name>
                 :                      ();
        die "Unknown query type '$type'" if !@cols;

        push @args, join ' ', @{ $query{$type} };
        my $cols = join ', ', @cols;
        push @match, qq[MATCH ($cols) AGAINST ( ? )];
    }
    return( join("\nAND ", @match), @args );
}

sub trim { my $str = shift; $str =~ s/\A\s*//; $str =~ s/\s*\z//; return $str; }

1;
