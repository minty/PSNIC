package PSNIC::Module::Parser;

use Moose;
use PPI::Document;
use Pod::Simple::HTML;
use Pod::Simple::PullParser;

has filepath => (
    is      => 'ro',
    isa     => 'Str',
);
has $_ => (
    is      => 'rw',
    isa     => 'Str',
    default => '',
) for qw<raw_pod pod_title pod_description pod_html comments code>;
has subroutines => (
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
);
has pod_headings => (
    is      => 'rw',
    isa     => 'ArrayRef[HashRef]',
    default => sub { [] },
);

sub parse_content {
    my ($doc, $token) = @_;

    my $tokens = $doc->find($token)
        or return;
    return join "\n", map { $_->content } @$tokens;
}

sub parse {
    my ($self) = @_;

    my $doc = PPI::Document->new($self->filepath)
        or return;

    $self->comments( parse_content($doc, 'PPI::Token::Comment') );
    $self->raw_pod( parse_content($doc, 'PPI::Token::Pod') );
    $self->parse_pod;

    # Subroutines, excluding anonymous ones
    my $matches = $doc->find(sub {
        $_[1]->isa('PPI::Statement::Sub') and $_[1]->name
    });
    $self->subroutines([ map { $_->name } @$matches ])
        if $matches;

    # code = doc - comments - pod
    $doc->prune('PPI::Token::Comment');
    $doc->prune('PPI::Token::Pod');
    $self->code($doc->serialize);
}

sub parse_pod {
    my ($self) = @_;

    my $html;
    my ($parser) = $self->pod_simple_html_parser(\$html)
        or return;

    # Sadly these re-stash the tokens they've pulled ...
    # XXX I'm unconvinced these actually are the right thing.
    # They fail on AnyData::Format::CSV
    $self->pod_title( $parser->get_title );
    $self->pod_description( $parser->get_description );

    # So re-strip those sections
    $self->strip_pod_section($parser, $_) for qw<NAME DESCRIPTION>;

    # Let Pod::Simple::HTML work it's magic on our filtered token stream
    $parser->run;
    $html =~ s/^.*<!-- start doc -->//s;
    $html =~ s/<!-- end doc -->.*$//s;
    $self->pod_html($html);

    # Extract all the pod section headings.
    $self->parse_pod_headings;
}

sub strip_pod_section {
    my ($self, $parser, $section) = @_;

    my (@tokens, @stash);
    my $title = my $state = '';
    while(my $tkn = $parser->get_token) {
        if($tkn->is_start && $tkn->tagname eq 'head1') {
            # If we've past the section, we can stop.
            # Push other section tokens (if any) back
            if ($title eq $section) {
                last;
            }
            push @tokens, @stash
                if @stash
                && $title !~ /\A $section \z/xms;
            @stash = ();
            $title = '';
            $state = 'head1';
        }
        elsif ($tkn->is_end && $tkn->tagname eq 'head1') {
            $state = '';
        }
        elsif($tkn->is_text && $state eq 'head1') {
            $title = $tkn->text;
        }
        push @stash, $tkn;
    }
    $parser->unget_token(@tokens);
}

sub pod_simple_html_parser {
    my ($self, $html) = @_;

    my $pod_src = $self->raw_pod
        or return;

    my $parser = Pod::Simple::HTML->new;
    $parser->perldoc_url_prefix("/perldoc?");  # XXX
    $parser->index(0);
    $parser->no_whining(1);
    $parser->no_errata_section(1);
    $parser->output_string( $html );
    $parser->set_source( \$pod_src );

    return $parser;
}

# Parse the pod, loop through each token looking for a heading.  Record the
# heading name/label and the indentation level.
sub parse_pod_headings {
    my ($self) = @_;

    my $pod = $self->raw_pod
        or return;

    my $parser = Pod::Simple::PullParser->new;
    $parser->set_source(\$pod);

    my ($in_head, $level, @headings);
    while(my $tkn = $parser->get_token) {
        ($in_head, $level) = (1, $1)
            if $tkn->is_start
            && $tkn->tagname =~ /\A head(\d)/x;

        if ($in_head && $tkn->is_text) {
            push @headings, {
                level => $level,
                label => $tkn->text,
            };
            ($in_head, $level) = ();
        }
    }
    $self->pod_headings(\@headings);
}

1;
