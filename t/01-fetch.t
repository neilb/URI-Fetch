# $Id: 01-fetch.t 1745 2005-01-01 00:39:49Z btrott $

use strict;
use Test::More tests => 39;
use URI::Fetch;

use constant BASE      => 'http://stupidfool.org/perl/feeds/';
use constant URI_OK    => BASE . 'ok.xml';
use constant URI_MOVED => BASE . 'moved.xml';
use constant URI_GONE  => BASE . 'gone.xml';
use constant URI_ERROR => BASE . 'error.xml';

my($res, $xml, $etag, $mtime);

## Test a basic fetch.
$res = URI::Fetch->fetch(URI_OK);
ok($res);
is($res->status, URI::Fetch::URI_OK());
is($res->http_status, 200);
ok($etag = $res->etag);
ok($mtime = $res->last_modified);
is($res->uri, URI_OK);
ok($xml = $res->content);

## Test a fetch using last-modified.
$res = URI::Fetch->fetch(URI_OK, LastModified => $mtime);
ok($res);
is($res->http_status, 304);
is($res->status, URI::Fetch::URI_NOT_MODIFIED());
is($res->content, undef);

## Test a fetch using etag.
$res = URI::Fetch->fetch(URI_OK, ETag => $etag);
ok($res);
is($res->http_status, 304);
is($res->status, URI::Fetch::URI_NOT_MODIFIED());
is($res->content, undef);

## Test a fetch using both.
$res = URI::Fetch->fetch(URI_OK, ETag => $etag, LastModified => $mtime);
ok($res);
is($res->http_status, 304);
is($res->status, URI::Fetch::URI_NOT_MODIFIED());
is($res->content, undef);

## Test a regular fetch using a cache.
my $cache = My::Cache->new;
$res = URI::Fetch->fetch(URI_OK, Cache => $cache);
ok($res);
is($res->http_status, 200);
ok($etag = $res->etag);
ok($mtime = $res->last_modified);
ok($xml = $res->content);

## Now hit the same URI again using the same cache, and hope to
## get back a not-modified response with the full content from the cache.
$res = URI::Fetch->fetch(URI_OK, Cache => $cache);
ok($res);
is($res->http_status, 304);
is($res->status, URI::Fetch::URI_NOT_MODIFIED());
is($res->etag, $etag);
is($res->last_modified, $mtime);
is($res->content, $xml);

## Test fetch of "moved permanently" resouce.
$res = URI::Fetch->fetch(URI_MOVED);
ok($res);
is($res->status, URI::Fetch::URI_MOVED_PERMANENTLY());
is($res->http_status, 200);
is($res->uri, URI_OK);

## Test fetch of "gone" resource.
$res = URI::Fetch->fetch(URI_GONE);
ok($res);
is($res->status, URI::Fetch::URI_GONE());
is($res->http_status, 410);

## Test fetch of unhandled error.
$res = URI::Fetch->fetch(URI_ERROR);
ok(!$res);
ok(URI::Fetch->errstr);

package My::Cache;
sub new { bless {}, shift }
sub get { $_[0]->{ $_[1] } }
sub set { $_[0]->{ $_[1] } = $_[2] }
