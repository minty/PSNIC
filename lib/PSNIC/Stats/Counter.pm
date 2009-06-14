package PSNIC::Stats::Counter;

use Moose;
use DateTime;

has tasks => (
    is            => 'rw',
    isa           => 'Int',
    required      => 1,
    documentation => 'The number of tasks we will be doing',
);
has counter => (
    is            => 'rw',
    isa           => 'Int',
    default       => 0,
    documentation => 'How many tasks we have done to date',
);
has started_at => (
    is            => 'ro',
    isa           => 'DateTime',
    default       => sub { return DateTime->now(time_zone => 'local') },
    documentation => 'When work began',
);
has report_every => (
    is            => 'rw',
    isa           => 'Int',
    default       => 50,
    documentation => 'Reports every N interations',
);
has info => (
    is            => 'rw',
    isa           => 'CodeRef',
    default       => sub { sub { warn @_, "\n" } },
    documentation => 'How we emit messages/reports',
);
has report => (
    is            => 'rw',
    isa           => 'CodeRef',
    builder       => 'default_report',
    documentation => 'The format of reports',
);
sub default_report {
    my ($self) = @_;
    return sub {
        my ($self) = @_;
        $self->info->(join '',
            $self->counter,
            '/',
            $self->tasks,
            ' in ',
            $self->running_in_seconds,
            'secs. ',
            $self->eta_in_seconds,
            'secs left, finish at ~',
            $self->eta,
        );
    }
}
sub tick {
    my ($self) = @_;
    $self->counter($self->counter + 1);
    $self->report->($self) if $self->report_due;
}
sub report_due {
    my ($self) = @_;
    return ($self->counter % $self->report_every) == 0;
}
sub running_in_seconds {
    my ($self) = @_;
    return DateTime->now(time_zone=>'local')->epoch - $self->started_at->epoch;
}
sub eta_in_seconds {
    my ($self) = @_;
    return 0 if !$self->counter;
    my $run_time = $self->running_in_seconds;
    my $avg_per_task = $run_time / $self->counter;
    my $remaining    = int($avg_per_task * $self->tasks) - $run_time;
    return $remaining > 0 ? $remaining : 0;
}
sub eta {
    my ($self) = @_;
    return DateTime->now(time_zone => 'local')
                   ->add(seconds => $self->eta_in_seconds);
}

1;
