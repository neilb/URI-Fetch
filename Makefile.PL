use inc::Module::Install;
name 'URI-Fetch';
all_from 'lib/URI/Fetch.pm';
readme_from 'lib/URI/Fetch.pm';

requires 'Class::ErrorHandler';
requires 'LWP';
requires 'URI';
requires 'Storable';
requires 'Compress::Zlib';

test_requires 'Test::More';

use_test_base;
auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
