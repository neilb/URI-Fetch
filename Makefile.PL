# $Id: Makefile.PL 1835 2005-05-25 22:52:11Z btrott $

use inc::Module::Install;

name('URI-Fetch');
abstract('Smart URI fetching/caching');
author('Benjamin Trott <ben+cpan@stupidfool.org>');
version_from('lib/URI/Fetch.pm');
license('perl');
no_index(directory => 't');
sign(1);

include('ExtUtils::AutoInstall');

requires('Class::ErrorHandler');
requires('LWP');
requires('URI');
requires('Storable'),

features(
    'GZIP Support' => [
        -default => 1,
        recommends('Compress::Zlib'),
    ],

    'Caching Support' => [
        -default => 0,
        recommends('Cache'),
    ],
);

auto_include();
auto_install();

&WriteAll;
