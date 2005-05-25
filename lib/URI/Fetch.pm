# $Id: Fetch.pm 1835 2005-05-25 22:52:11Z btrott $

package URI::Fetch;
use strict;
use base qw( Class::ErrorHandler );

use LWP::UserAgent;
use Carp qw( croak );
use URI;
use URI::Fetch::Response;
use Storable;

our $VERSION = '0.02';

our $HAS_ZLIB;
BEGIN {
    $HAS_ZLIB = eval "use Compress::Zlib (); 1;";
}

use constant URI_OK                => 200;
use constant URI_MOVED_PERMANENTLY => 301;
use constant URI_NOT_MODIFIED      => 304;
use constant URI_GONE              => 410;

sub fetch {
    my $class = shift;
    my($uri, %param) = @_;

    # get user parameters
    my $cache        = delete $param{Cache};
    my $ua           = delete $param{UserAgent};
    my $p_etag       = delete $param{ETag};
    my $p_lastmod    = delete $param{LastModified};
    my $content_hook = delete $param{ContentAlterHook};
    croak("Unknown parameters: " . join(", ", keys %param))
        if %param;

    my $ref;
    if ($cache && (my $blob = $cache->get($uri))) {
        $ref = Storable::thaw($blob);
    }

    $ua ||= LWP::UserAgent->new;
    $ua->agent(join '/', $class, $class->VERSION);

    my $req = HTTP::Request->new(GET => $uri);
    if ($HAS_ZLIB) {
        $req->header('Accept-Encoding', 'gzip');
    }
    if (my $etag = ($p_etag || $ref->{ETag})) {
        $req->header('If-None-Match', $etag);
    }
    if (my $ts = ($p_lastmod || $ref->{LastModified})) {
        $req->if_modified_since($ts);
    }

    my $res = $ua->request($req);
    my $feed = URI::Fetch::Response->new;
    $feed->uri($uri);
    $feed->http_status($res->code);
    $feed->http_response($res);
    if ($res->previous && $res->previous->code == HTTP::Status::RC_MOVED_PERMANENTLY()) {
        $feed->status(URI_MOVED_PERMANENTLY);
        $feed->uri($res->previous->header('Location'));
    } elsif ($res->code == HTTP::Status::RC_GONE()) {
        $feed->status(URI_GONE);
        $feed->uri(undef);
        return $feed;
    } elsif ($res->code == HTTP::Status::RC_NOT_MODIFIED()) {
        $feed->status(URI_NOT_MODIFIED);
        $feed->content($ref->{Content});
        $feed->etag($ref->{ETag});
        $feed->last_modified($ref->{LastModified});
        return $feed;
    } elsif (!$res->is_success) {
        return $class->error($res->message);
    } else {
        $feed->status(URI_OK);
    }
    $feed->last_modified($res->last_modified);
    $feed->etag($res->header('ETag'));
    my $content = $res->content;
    if ($res->content_encoding && $res->content_encoding eq 'gzip') {
        $content = Compress::Zlib::memGunzip($content);
    }

    # let caller-defined transform hook modify the result that'll be
    # cached.  perhaps the caller only wants the <head> section of
    # HTML, or wants to change the content to a parsed datastructure
    # already serialized with Storable.
    if ($content_hook) {
        croak("ContentAlterHook is not a subref") unless ref $content_hook eq "CODE";
        $content_hook->(\$content);
    }

    $feed->content($content);

    if ($cache) {
        $cache->set($uri, Storable::freeze({
            ETag         => $feed->etag,
            LastModified => $feed->last_modified,
            Content      => $feed->content,
        }));
    }
    $feed;
}

1;
__END__

=head1 NAME

URI::Fetch - Smart URI fetching (for syndication feeds, in particular)

=head1 SYNOPSIS

    use URI::Fetch;

    ## Simple fetch.
    my $res = URI::Fetch->fetch('http://example.com/atom.xml')
        or die URI::Fetch->errstr;

    ## Fetch using specified ETag and Last-Modified headers.
    my $res = URI::Fetch->fetch('http://example.com/atom.xml',
            ETag => '123-ABC',
            LastModified => time - 3600,
    )
        or die URI::Fetch->errstr;

    ## Fetch using an on-disk cache that URI::Fetch manages for you.
    my $cache = Cache::File->new( cache_root => '/tmp/cache' );
    my $res = URI::Fetch->fetch('http://example.com/atom.xml',
            Cache => $cache
    )
        or die URI::Fetch->errstr;

=head1 DESCRIPTION

I<URI::Fetch> is a smart client for fetching syndication feeds (RSS, Atom,
and others) in an intelligent, bandwidth- and time-saving way. That means:

=over 4

=item * GZIP support

If you have I<Compress::Zlib> installed, I<URI::Fetch> will automatically
try to download a compressed version of the content, saving bandwidth (and
time).

=item * I<Last-Modified> and I<ETag> support

If you use a local cache (see the I<Cache> parameter to I<fetch>),
I<URI::Fetch> will keep track of the I<Last-Modified> and I<ETag> headers
from the server, allowing you to only download feeds that have been
modified since the last time you checked.

=item * Proper understanding of HTTP error codes

Certain HTTP error codes are special, particularly when fetching syndication
feeds, and well-written clients should pay special attention to them.
I<URI::Fetch> can only do so much for you in this regard, but it gives
you the tools to be a well-written client.

The response from I<fetch> gives you the raw HTTP response code, along with
special handling of 2 codes:

=over 4

=item * 304 (Moved Permanently)

Signals that a feed has moved permanently, and that your database of feeds
should be updated to reflect the new URI.

=item * 410 (Gone)

Signals that a feed is gone and will never be coming back, and should be
removed from your database of feeds (or whatever you're using).

=back

=head1 USAGE

=head2 URI::Fetch->fetch($uri, %param)

Fetches a syndication feed identified by the URI I<$uri>.

On success, returns a I<URI::Fetch::Response> object; on failure, returns
C<undef>.

I<%param> can contain:

=over 4

=item * LastModified

=item * ETag

I<LastModified> and I<ETag> can be supplied to force the server to only
return the full feed if it's changed since the last request. If you're
writing your own feed client, this is recommended practice, because it
limits both your bandwidth use and the server's.

If you'd rather not have to store the I<LastModified> time and I<ETag>
yourself, see the I<Cache> parameter below (and the L<SYNOPSIS> above).

=item * Cache

If you'd like I<URI::Fetch> to cache responses between requests, provide
the I<Cache> parameter with an object supporting the L<Cache> API (e.g.
I<Cache::File>, I<Cache::Memory>). Specifically, an object that supports
C<$cache-E<gt>get($key)> and C<$cache-E<gt>set($key, $value, $expires)>.

If supplied, I<URI::Fetch> will store the feed content, ETag, and
last-modified time of the response in the cache, and will pull the
content from the cache on subsequent requests if the feed returns a
Not-Modified response.

=item * UserAgent

Optional.  You may provide your own LWP::UserAgent instance.  Look
into L<LWPx::ParanoidUserAgent> if you're fetching URLs given to you
by possibly malicious parties.

=item * ContentAlterHook

Optional.  A subref that gets called with a scalar reference to your
content so you can modify the content before it's returned and before
it's put in cache.

For instance, you may want to only cache the E<lt>headE<gt> section of
an HTML document, or you may want to take a feed URL and cache only a
pre-parsed version of it.  If you modify the scalarref given to your
hook and change it into a hashref, scalarref, or some blessed object,
that same value will be returned to you later on not-modified
responses.

=back

=head1 LICENSE

I<URI::Fetch> is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR & COPYRIGHT

Except where otherwise noted, I<URI::Fetch> is Copyright 2004 Benjamin
Trott, ben+cpan@stupidfool.org. All rights reserved.

=cut
