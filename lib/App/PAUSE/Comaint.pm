package App::PAUSE::Comaint;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use App::PAUSE::Comaint::PackageScanner;
use WWW::Mechanize;
use ExtUtils::MakeMaker qw(prompt);

sub new {
    my($class) = @_;
    bless { mech => WWW::Mechanize->new }, $class;
}

sub mech { $_[0]->{mech} }

sub _scanner {
    App::PAUSE::Comaint::PackageScanner->new(
        "$ENV{HOME}/.cpanm/sources/http%www.cpan.org/02packages.details.txt",
    )
}

sub run {
    my($self, $module, $comaint) = @_;

    unless ($module && $comaint) {
        die "Usage: comaint Module AUTHOR\n";
    }

    my $scanner = $self->_scanner;
    my @packages = $scanner->find($module);

    @packages or die "Couldn't find module '$module' in 02packages\n";

    $self->login_pause;
    $self->_load_comaint_form;
    $self->make_comaint($comaint, \@packages);
}

sub run_abandon {
    my($self, @modules) = @_;

    unless (@modules) {
        die "Usage: abandon-comaint Module [Module2 Module3 ...] \n";
    }

    my $scanner = $self->_scanner;
    my @packages = map $scanner->find($_), @modules;

    @packages or die "Couldn't find any of " . join(', ', @modules) . " in 02packages\n";

    $self->login_pause;
    $self->_load_abandon_comaint_form;
    $self->abandon_comaint(\@packages);
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

    $self->mech->credentials($self->get_credentials);
    $self->mech->get("https://pause.perl.org/pause/authenquery?ACTION=share_perms");
    $self->mech->form_number(1);
}

sub _load_comaint_form {
    my $self = shift;

    $self->mech->click('weaksubmit_pause99_share_perms_makeco');

    $self->mech->content =~ /Select a co-maintainer/
        or die "Something is wrong with Screen-scraping: ", $self->mech->content;
}

sub _load_abandon_comaint_form {
    my $self = shift;

    $self->mech->click('weaksubmit_pause99_share_perms_remome');

    $self->mech->content =~ /Select one or more namespaces/
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
        my $msg = "Couldn't find following modules in your maint list:\n";
        for my $module (sort keys %try) {
            $msg .= "  $module\n";
        }
        die $msg;
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

sub abandon_comaint {
    my($self, $packages) = @_;

    my %try = map { $_ => 1 } @$packages;

    my $form = $self->mech->form_number(1);

    for my $input ($form->find_input('pause99_share_perms_remome_m')) {
        my $value = ($input->possible_values)[1];
        if ($try{$value}) {
            $input->check;
            delete $try{$value};
        }
    }

    if (keys %try) {
        my $msg = "Couldn't find following modules in your comaint list:\n";
        for my $module (sort keys %try) {
            $msg .= "  $module\n";
        }
        die $msg;
    }

    print "Going to abandon comaint of the following modules.\n\n";
    for my $package (@$packages) {
        print "  $package\n";
    }
    print "\n";

    my $value = prompt "Are you sure?", "y";
    return if lc($value) ne 'y';

    $self->mech->click_button(value => 'Give Up');

    if ($self->mech->content =~ /<p>(Removed .* from co-maint.*)<\/p>/) {
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

App::PAUSE::Comaint - Make someone co-maint of your module on PAUSE/CPAN

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 COPYRIGHT

Copyright 2013- Tatsuhiko Miyagawa

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<comaint>

=cut
