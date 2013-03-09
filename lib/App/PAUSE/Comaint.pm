package App::PAUSE::Comaint;

use strict;
use 5.008_001;
our $VERSION = '0.01';

package App::PAUSE::Comaint::PackageScanner;
use Moo;
has 'file', is => 'rw';

use constant DONE => "SCAN_DONE\n";

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


package App::Comaint;
use Moo;
use WWW::Mechanize;
use ExtUtils::MakeMaker qw(prompt);

has 'mech', is => 'rw';

sub run {
    my($self, $module, $comaint) = @_;

    my $scanner = PackageScanner->new(file => "$ENV{HOME}/.cpanm/sources/http%www.cpan.org/02packages.details.txt");
    my @packages = $scanner->find($module);

    @packages or die "Couldn't find moduel $module in 02packages\n";

    $self->login_pause;
    $self->make_comaint($comaint, \@packages);
}

sub get_credentials {
    my $self = shift;

    open my $in, "<", "$ENV{HOME}/.pause"
        or die "Can't open ~/.pause: $!";
    my %rc;
    while (<$in>) {
        /^(\S+)\s+(.*)/ and $rc{$1} = $2;
    }

    return @rc{qw(user password)};
}

sub login_pause {
    my $self = shift;

    $self->mech(WWW::Mechanize->new);
    $self->mech->credentials($self->get_credentials);
    $self->mech->get("https://pause.perl.org/pause/authenquery?ACTION=share_perms");

    $self->mech->form_number(1);
    $self->mech->click('weaksubmit_pause99_share_perms_makeco');

    $self->mech->content =~ /Select a co-maintainer/
        or die "Something is wrong with Screen-scraping: ", $self->mech->content;
}

sub make_comaint {
    my($self, $author, $packages) = @_;

    my %try = map { $_ => 1 } @$packages;

    my $form = $self->mech->form_number(1);

    for my $input ($form->find_input('pause99_share_perms_makeco_m')) {
        my $value = ($input->possible_values)[1];
        if ($try{$value}) {
            $input->check;
            delete $try{$value};
        }
    }

    if (keys %try) {
        die "Couldn't find following modules in your maint list: ", join(", ", sort keys %try), "\n";
    }

    $form->find_input("pause99_share_perms_makeco_a")->value($author);

    print "Going to make $author as a comaint of the following modules.\n\n";
    for my $package (@$packages) {
        print "  $package\n";
    }
    print "\n";

    my $value = prompt "Are you sure?", "y";
    return if lc($value) ne 'y';

    $self->mech->click_button(value => 'Make Co-Maintainer');

    if ($self->mech->content =~ /<p>(Added .* to co-maint.*)<\/p>/) {
        print "\n", $1, "\n";
    } else {
        warn "Something's wrong: ", $self->mech->content;
    }
}


1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

App::PAUSE::Comaint -

=head1 SYNOPSIS

  use App::PAUSE::Comaint;

=head1 DESCRIPTION

App::PAUSE::Comaint is

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 COPYRIGHT

Copyright 2013- Tatsuhiko Miyagawa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
