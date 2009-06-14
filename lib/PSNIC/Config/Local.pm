package PSNIC::Config::Local;

# First load psnic.conf then apply any overrides in psnic_local.conf
# We assume the configs are all one directory above any & all
# script/executable files.

use FindBin;
use Config::JFDI;
use Path::Class qw<file>;

use Exporter qw<import>;
our @EXPORT_OK = qw<get_conf get_conf_path>;

my $CONF;

# XXX Replace this with alternative logic
# my $file = __FILE__;
# We know where we sit in the heirarchy ($working_dir/lib/.../Local.pm)
# Thus if we know our absolute path, we can infer the base_dir by
# chopping off the right hand side accordingly.
sub base_dir { return "$FindBin::Bin/../" }

sub load_config {
    my ($self) = @_;

    my $config = Config::JFDI->new(path => "$FindBin::Bin/../psnic.conf");
    $CONF = $config->load;
}

sub get_conf {
    my ($key) = @_;

    load_config() if !$CONF;

    my $value = $CONF;
    for (split /\./, $key) {
        return if !exists $value->{$_};
        $value = $value->{$_};
    }
    return $value;
}

sub get_conf_path {
    my ($key) = @_;

    my $path = get_conf($key);
    return undef if !defined $path;
    my $file = file($path);
    return $file->is_absolute ? $file : file(base_dir(), $filename);
}

1;
