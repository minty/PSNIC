# IMPORTANT: if you delete this file your app will not work as
# expected.  you have been warned
use inc::Module::Install;

name 'PSNIC';
all_from 'lib/PSNIC.pm';

perl_version '5.008';

requires 'Catalyst::Runtime' => '5.7014';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Action::RenderView';
requires 'DBD::mysql';
requires 'parent';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
requires 'Parse::CPAN::Cached' => 0.01;
requires 'App::Cache' => 0.35;
requires 'Config::JFDI' => 0.06;
requires 'Data::JavaScript::Anon' => 1.03;
requires 'List::MoreUtils' => 0.22;
requires 'LWP::UserAgent';
requires 'Module::Build' => 0.31;
requires 'Moose' => 0.72;
requires 'Path::Class' => 0.16;
requires 'Pod::Simple' => 3.07;
requires 'PPI::Document' => 1.203;

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
