# $Id: Makefile.PL 1741 2004-12-31 23:48:51Z btrott $

use inc::Module::Install;

name('URI-Fetch');
abstract('Smart URI fetching (for syndication feeds, in particular)');
author('Benjamin Trott <ben+cpan@stupidfool.org>');
version_from('lib/URI/Fetch.pm');
license('perl');
no_index(directory => 't');
sign(1);

include('ExtUtils::AutoInstall');

requires('Class::ErrorHandler');
requires('LWP');
requires('URI');

features(
    'GZIP Support' => [
        -default => 1,
        recommends('Compress::Zlib'),
    ],

    'Caching Support' => [
        -default => 0,
        recommends('Cache'),
        recommends('Storable'),
    ],
);

auto_include();
auto_install();

&WriteAll;
