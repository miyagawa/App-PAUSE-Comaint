use inc::Module::Install;
all_from 'lib/App/PAUSE/Comaint.pm';
readme_from('bin/comaint');
install_script 'bin/comaint';
build_requires 'Test::More', 0.88;
requires 'LWP::Protocol::https';
requires 'WWW::Mechanize';
test_requires 'Test::Requires';
auto_set_repository();
resources
  homepage      => "https://github.com/miyagawa/App-PAUSE-Comaint",
  bugtracker    => "https://github.com/miyagawa/App-PAUSE-Comaint/issues";
auto_provides;
WriteAll;
