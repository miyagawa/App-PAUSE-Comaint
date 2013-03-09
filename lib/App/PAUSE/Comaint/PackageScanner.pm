package App::PAUSE::Comaint::PackageScanner;
use strict;
use constant DONE => "SCAN_DONE\n";

sub new {
    my($class, $file) = @_;
    my $self = { file => $file };
    bless $self, $class;
}

sub file { $_[0]->{file} }

sub find {
    my($self, $want) = @_;

    my $found;

    $self->scan(sub {
        my($module, $version, $dist) = @_;
        if ($module eq $want) {
            $found = $dist;
            die DONE;
        }
    });

    my @packages;

    if ($found) {
        $self->scan(sub {
            my($module, $version, $dist) = @_;
            push @packages, $module if $dist eq $found;
        });
    }

    return @packages;
}

sub scan {
    my($self, $cb) = @_;

    open my $fh, "<", $self->file
        or die "$!: run `cpanm --mirror-only strict` to regenerate 02packages cache\n";
    my $in_header = 1;
    while (<$fh>) {
        if (/^$/) {
            $in_header = 0;
            next;
        }
        next if $in_header;

        if (/^(\S+)\s+(\S+)  (\S+)/) {
            eval { $cb->($1, $2, $3) };
            return if $@ eq DONE;
            die $@ if $@;
        }
    }
}

1;
