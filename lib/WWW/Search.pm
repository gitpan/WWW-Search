#!/usr/local/bin/perl -w

#
# Search.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Search.pm,v 1.60 1998/08/27 17:28:57 johnh Exp $
#
# A complete copyright notice appears at the end of this file.
# 


package WWW::Search;

=head1 NAME

WWW::Search - Virtual base class for WWW searches


=head1 SYNOPSIS

    require WWW::Search;
    $search_engine = "AltaVista";
    $search = new WWW::Search($search_engine);


=head1 DESCRIPTION

This class is the parent for all access methods supported by the
C<WWW::Search> library.  This library implements a Perl API
to web-based search engines.

Current search engines supported include
AltaVista (both web and news),
Dejanews,
Excite (web only),
Gopher,
HotBot (web only),
Infoseek (e-mail, web, and news),
Lycos,
Magellan,
PLweb,
SFgate,
Simple (retrieve links on a page),
Verity.

Search results are limited and there is a pause between each request 
for results to avoid overloading either the client or the server.

=head2 Sample program

Using the library should be straightforward.
Here's a sample program:

    my($search) = new WWW::Search('AltaVista');
    $search->native_query(WWW::Search::escape_query($query));
    my($result);
    while ($result = $search->next_result()) {
	print $result->url, "\n";
    };

Results are objects of C<WWW::SearchResult>
(see L<WWW::SearchResult>) .


=head1 SEE ALSO

For more details see L<LWP>.

For specific search engines, see L<WWW::Search::TheEngineName>
(replacing TheEngineName with a particular search engine).

For details about the results of a search,
see L<WWW::SearchResult>.


=head1 METHODS AND FUNCTIONS

=cut
#'

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw(escape_query unescape_query generic_option);
$VERSION = '1.021';
require LWP::MemberMixin;
@ISA = qw(Exporter LWP::MemberMixin);
use LWP::UserAgent;
use LWP::RobotUA;
use HTTP::Status;
use HTTP::Request;
use HTTP::Response;

use Carp ();
use URI::Escape;

# my %ImplementedBy = (); # scheme => classname


# internal
($SEARCH_BEFORE, $SEARCH_UNDERWAY, $SEARCH_DONE) = (1..10);


=head2 new

To create a new WWW::Search, call
    $search = new WWW::Search('SearchEngineName');
where SearchEngineName is replaced with a particular search engine.
For example:
    $search = new WWW::Search('AltaVista');

If no search engine is specified a default will be chosen for you.

The next step is usually:
    $search->native_query('search-engine-specific+query+string');

=cut


# the default (not currently more configurable :-< )
$default_engine = 'AltaVista';
$default_agent_name = "WWW::Search/$VERSION";
$default_agent_e_mail = 'johnh@isi.edu';

sub new
{ 
    my($class, $engine) = @_;

    $engine = $default_engine if (!defined($engine));
    # Load the engine, if necessary.
    my($subclass) = "${class}::$engine";
    if (!defined(&$subclass)) {
	eval "use $subclass";
	Carp::croak("unknown search engine back-end $engine ($@)") if ($@);
    };

    my $self = bless {
	engine => $engine,
	state => $SEARCH_BEFORE,
	next_to_return => 0,
	maximum_to_retrieve => 500,  # both pages and hits
	number_retrieved => 0,
	requests_made => 0,
	interrequest_delay => 0.25,  # in seconds
	agent_name => $default_agent_name,
	agent_e_mail => $default_agent_e_mail,
	http_proxy => undef,
	timeout => 60,
	debug => 0,
	search_from_file => undef,
	search_to_file => undef,
	search_to_file_index => 0,
	# variable initialization goes here
    }, $subclass;
    return $self;
}


=head2 native_query

Specify a query (and optional options) to the current search object.
The query and options must be escaped; call L<WWW::Search/escape_query>
to escape a plain query.
The actual search is not actually begun until C<results> or
C<next_result> is called.

Example:

	$search->native_query('search-engine-specific+query+string',
		{ option1 => 'able', option2 => 'baker' } );

The hash of options following the query string is optional.  
The query string is back-end specific.
There are two kinds of options:
options specific to the back-end
and generic options applicable to mutliple back-ends.

Generic options all begin with ``search_''.
Currently a few are supported:

=over 4

=item search_url
Specifies the root of the URL for the 

=item search_debug
Enables back-end debugging.

=item search_parse_debug
Enables back-end parser debugging.

=item search_method
Specifies the HTTP method (C<GET> or C<POST>) for HTTP-based queries.

=item search_to_file FILE
Causes the search results to be saved in a set of files 
prefixed by FILE.

=item search_from_file FILE
Reads a search from a set of files prefixed by FILE.

=back

Some back-ends may not implement generic options,
but any which do implement them must provide these semantics.

Back-end-specific options are described
in the documentation for each back-ends.
Typically they are packed together to create the query portion of
the final URL.

Details about how the search string and option hash are interpreted
in the search-engine-specific manual pages
(WWW::Search::SearchEngineName).

After C<native_query>, the next step is usually:

    @results = $search->results();

or

    while ($result = $search->next_result()) {
	# do_something;
    };

=cut
#'

sub native_query {
    my($self) = shift;
    return $self->_elem('native_query', @_)
	if ($#_ != 1);
    $self->{'native_query'} = $_[0];
    $self->{'native_options'} = $_[1];
    # promote generic options
    my($opts_ref) = $_[1];
    foreach (keys %$opts_ref) {
	$self->{$_} = $opts_ref->{$_}
	    if (generic_option($_));
    };
}

=head2 approximate_result_count

Some back-ends indicate how many hits they've found.
Typically this is an approximate value.
=cut
#'
sub approximate_result_count { return shift->_elem('approx_count', @_); }


=head2 results

Return all the results of a query as a reference to array 
of SearchResult objects.

Example:
    @results = $search->results();
    foreach $result (@results) {
        print $result->url(), "\n";
    };

On error, results() will return undef and set C<response()>
to the HTTP response code.

=cut

sub results
{
    my($self) = shift;
    Carp::croak "search not yet specified"
	if (!defined($self->{'native_query'}));
    while ($self->retrieve_some()) {
	# leave them in the cache
    };
    if ($#{$self->{cache}} >= $self->{maximum_to_retrieve}) {
        return @{$self->{cache}}[0..($self->{maximum_to_retrieve}-1)];
    } else {
        return @{$self->{cache}};
    };
}

=head2 next_result

Return each result of a query as a SearchResult object.

Example:
    while ($result = $search->next_result()) {
	print $result->url(), "\n";
    };

On error, results() will return undef and set C<response()>
to the HTTP response code.

=cut
sub next_result
{
    my($self) = shift;
    Carp::croak "search not yet specified"
	if (!defined($self->{'native_query'}));
    return undef if ($self->{next_to_return} >= $self->{maximum_to_retrieve});
    for (;;) {
        # Something in the cache?  Return it.
        if ($self->{next_to_return} <= $#{$self->{cache}}) {
            my($i) = ($self->{next_to_return})++;
            return ${$self->{cache}}[$i];
        };
        # Done?  Say so.
        if ($self->{state} == $SEARCH_DONE) {
            return undef;
        };
        # Try to fill cache, then try again.
	$self->retrieve_some();
    };
}


=head2 response

Return the HTTP Response code for the last query
(see L<HTTP::Response>).
If the query returns C<undef>,
errors could be reported like this:

    my($response) = $search->response();
    if ($response->is_success) {
	print "no search results\n";
    } else {
	print "error:  " . $response->as_string() . "\n";
    };

Note:  even if the back-end does not involve the web
it should return HTTP::Response-style codes.

=cut
sub response
{
    my($self) = shift;
    $self->{response} = new HTTP::Response(RC_OK)
	if (!defined($self->{response}));
    return $self->{response};
}


=head2 C<seek_result($offset)>

Set which result C<next_result> should return
(like C<lseek> in Unix).
Results are zero-indexed.

The only guaranteed valid offset is 0
which will replay the results from the beginning.
In particular, seeking past the end of the current cached
results probably won't do what you might think it should.

Results are cached, so this doesn't re-issue the query
or cause IO (unless you go off the end of the results).
To re-do the query, create a new search object.

Example:
    $search->seek_result(0);

=cut
sub seek_result
{
    my($self) = shift;
    return ($self->{next_to_return}) if ($#_ == -1);
    my($old) = $self->{next_to_return};
    $self->{next_to_return} = shift;
    return $old;
}


=head2 maximum_to_retrieve

The maximum number of hits to return.
Queries resulting in more than this many hits will return
the first hits, up to this limit.
Although this specifies a maximum limit,
search engines may impose a lower limit.

Defaults to 500.

Example:
    $max = $search->maximum_to_retrieve(100);

=cut
sub maximum_to_retrieve { return shift->_elem('maximum_to_retrieve', @_); }
# xxx: This should actually be called "maxiumum to return", I suppose.


=head2 timeout

The maximum length of time any portion of the query should take,
in seconds.

Defaults to 60.

Example:
    $search->timeout(120);

=cut
sub timeout { return shift->_elem('timeout', @_); }



=head2 opaque

This function provides an application a place to store
one opaque data element (or many via a Perl reference).
This facility is useful to (for example),
maintain client-specific information in each active query
when you have multiple concurrent queries. 

=cut
sub opaque { return shift->_elem('opaque', @_); }


=head2 escape_query

Escape a query.
Before queries are made special characters must be escaped
so that a proper URL can be formed.

This is like escaping a URL
but all non-alphanumeric characters are escaped and
and spaces are converted to "+"'s.

Example:
    $escaped = Search::escape_query('+lsam +replication');
(Returns "%22lsam+replication%22").

See also C<unescape_query>.

=cut
# '
sub escape_query {
    # code stolen from URI::Escape.pm.
    my($text) = @_;
    $text = "" if (!defined($text));
    # Default unsafe characters except for space. (RFC1738 section 2.2)
#    $text =~ s/([+\x00-\x1f"#%;<>?{}|\\\\^~`\[\]\x7F-\xFF])/$URI::Escape::escapes{$1}/g; #"
    # The modern trend seems to be to quote almost everything.
    $text =~ s/([^ A-Za-z0-9])/$URI::Escape::escapes{$1}/g; #"
    # space
    $text =~ s/ /+/g;
    return $text;
}

=head2 unescape_query

Unescape a query.
See C<escape_query> for details.

Example:
    $unescaped = Search::unescape_query('%22lsam+replication%22');
(Returns "+lsam +replication").

See also C<unescape_query>.

=cut
# '
sub unescape_query {
    # code stolen from URI::Escape.pm.
    my @copy = @_;
    for (@copy) {
	s/\+/ /g;
	s/%([\dA-Fa-f]{2})/chr(hex($1))/eg;
    }
    return wantarray ? @copy : $copy[0];
}



=head2 http_proxy

Set-up an HTTP proxy
(Perhaps for connections from behind a firewall.)

This routine should be called before the first retrival is attempted.

Example:

    $search->http_proxy("http://gateway:8080");

=cut
sub http_proxy { return shift->_elem('http_proxy', @_); }



=head2 http_request($method, $url)

Return the response from an http request,
handling debugging.  Requires that user_agent be setup.
For POST methods, query is split off of the URL and passed
in the request body.

=cut
sub http_request {
    my($self) = shift;
    my($method, $url) = @_;
    my($response);
    if ($self->{search_from_file}) {
	$response = $self->http_request_from_file($url);
    } else {
	# fetch it
        my($request);
	if ($method eq 'POST') {
	    my($uri_url) = new URI::URL($url);
	    my($equery) = $uri_url->equery;
	    $uri_url->equery(undef);   # we'll handle the query ourselves
	    $request = new HTTP::Request($method, $uri_url->abs());
	    $request->header('Content-Type', 'application/x-www-form-urlencoded');
	    $request->header('Content-Length', length $equery);
	    $request->content($equery);
	} else {
	    $request = new HTTP::Request($method, $url);
	};
	my($ua) = $self->{user_agent};

	$response = $ua->request($request);

	# save it for debugging?
	if ($self->{search_to_file} && $response->is_success) {
	    $self->http_request_to_file($url, $data, $response);
	};
    };
    return $response;
}

sub http_request_get_filename {
    my($self) = shift;
    # filename?
    if (!defined($self->{search_filename})) {
	my($fn) = $self->{search_from_file};
	$fn = $self->{search_to_file} if (!defined($fn));
	$self->{search_filename} = WWW::Search::unescape_query($fn);
    };
    my($fn) = $self->{search_filename};
    die "$0: bogus filename.\n" if (!defined($fn));
    return $fn;
}

sub http_request_from_file {
    my($self) = shift;
    my($url) = @_;

    my($fn) = $self->http_request_get_filename();

    # read index?
    if (!defined($self->{search_from_file_hash})) {
	open(TABLE, "<$fn") || die "$0: open $fn failed.\n";
	my($i) = 0;
	while (<TABLE>) {
	    chomp;
	    $self->{search_from_file_hash}{$_} = $i;
	    # print STDERR "$0: file index: $i <$_>\n";
	    $i++;
	};
	close TABLE;
    };

    # read file
    my($i) = $self->{search_from_file_hash}{$url};
    if (defined($i)) {
	# print STDERR "$0: saved request <$url> found in $fn.$i\n";
	# read the data
	open(FILE, "<$fn.$i") || die "$0: open $fn.$i\n";
	my($d) = "";
	while (<FILE>) {
	    $d .= $_;
	};
	close FILE;
	# make up the response
	my($r) = new HTTP::Response(RC_OK);
	$r->content($d);
	return $r;
    } else {
	print STDERR "$0: saved request <$url> not found.\n";
	my $r = new HTTP::Response(RC_NOT_FOUND);
	return $r;
    };
}

sub http_request_to_file {
    my($self) = shift;
    my($response) = pop;
    my($url) = @_;

    my($fn) = $self->http_request_get_filename();

    unlink($fn)
        if ($self->{search_to_file_index} == 0);
    open(TABLE, ">>$fn") || die "$0: open $fn\n";
    print TABLE "$url\n";
    close TABLE;
    my($i) = ($self->{search_to_file_index})++;
    open (FILE, ">$fn.$i") || die "$0: open $fn.$i\n";
    print FILE $response->content();
    close FILE;
}

=head2 split_lines (PRIVATE)

This internal routine splits data (typically the result of the web
page retrieval) into lines in a way that's OS independent.

=cut
#'
sub split_lines {
    # eventually this should be
    # use Socket qw(:crlf :DEFAULT);
    # split(/$CR?$LF/,$_[0])
    # but I don't have perl5.005 yet.
    #
    # This probably fails on an EBCDIC box
    # where input is in text mode.
    # Too bad Macs don't just use binmode like Windows boxen.
    my($self) = shift;
    return split(/\015?\012/, $_[0]);
}

=head2 generic_option (PRIVATE)

This internal routine checks if an option
is generic or back-end specific.
Currently all generic options begin with ``search_''.
This routine is not a method.

=cut
sub generic_option 
{
    my($option) = @_;
    return ($option =~ /^search_/);
}



=head2 setup_search (PRIVATE)

This internal routine does generic Search setup.
It calls C<native_setup_search> to do back-end specific setup.

=cut
#'

sub setup_search
{
    my($self) = @_;
    $self->{next_to_retrieve} = 1;
    $self->{cache} = ();
    $self->{number_retrieved} = 0;
    $self->{state} = $SEARCH_UNDERWAY;
    $self->native_setup_search($self->{'native_query'}, $self->{'native_options'});
}


=head2 user_agent($NON_ROBOT) (PRIVATE)

This internal routine creates a user-agent
for dervived classes that query the web.
If C<$NON_ROBOT>, a normal user-agent (rather than a robot-style user-agent)
is used.

Back-ends should use robot-style user-agents whereever possible.
Also, back-ends should call C<user_agent_delay> every page retrival
to avoid swamping search-engines.

=cut

sub user_agent
{
    my($self) = shift;
    my($non_robot) = @_;

    my($ua);
    if ($non_robot) {
	$ua = new LWP::UserAgent;
    } else {
	$ua = new LWP::RobotUA($self->{agent_name}, $self->{agent_e_mail});
	$ua->delay($self->{interrequest_delay}/60.0);
    };
    $ua->timeout($self->{'timeout'});
    $ua->proxy('http', $self->{'http_proxy'})
	if (defined($self->{'http_proxy'}));
    $self->{user_agent} = $ua;
}


=head2 user_agent_delay (PRIVATE)

Derived classes should call this between requests to remote
servers to avoid overloading them with many, fast back-to-back requests.

=cut
sub user_agent_delay {
    my($self) = @_;
    # sleep for a qarter second
    select(undef, undef, undef, $self->{interrequest_delay})
	 if ($self->{robot_p});
}

=head2 absurl (PRIVATE)

An internal routine to convert a relative URL into a absolute URL.  It
takes two arguments, the 'base' url (usually the search engine CGI
URL) and the URL to be converted.  Returns a URI::URL object.

=cut

sub absurl {
    my($self, $base, $url) = @_;

    #$url =~ s,^http:/([^/]),/$1,; #bogus sfgate URL

    my $link = new URI::URL $url, $base;
    return($link);
}


=head2 retrieve_some (PRIVATE)

An internal routine to interface with C<native_retrieve_some>.
Checks for overflow.

=cut

sub retrieve_some
{
    my($self) = shift;
    return undef
	if ($self->{state} == $SEARCH_DONE);
    # assume that caller as verified defined($self->{'native_query'}).
    $self->setup_search()
	if ($self->{state} == $SEARCH_BEFORE);

    # too many?
    if ($self->{number_retrieved} > $self->{'maximum_to_retrieve'}) {
        $self->{state} = $SEARCH_DONE;
	return;
    };
    if ($self->{requests_made} > $self->{'maximum_to_retrieve'}) {
        $self->{state} = $SEARCH_DONE;
	return;
    };

    # do it
    my($res) = $self->native_retrieve_some();
    $self->{requests_made}++;
    $self->{number_retrieved} += $res if (defined($res));
    $self->{state} = $SEARCH_DONE if (!defined($res));
    return $res;
}


=head1 IMPLEMENTING NEW BACK-ENDS

C<WWW::Search> supports back-ends to separate search engines.
Each back-end is implemented as a subclass of C<WWW::Search>.
L<WWW::Search::AltaVista> provides a good sample back-end.

A back-end usually has two routines,
C<native_retrieve_some> and C<native_setup_search>.

C<native_retrieve_some> is the core of a back-end.
It will be called periodically to fetch URLs.
Each call it should fetch a page with about 10 or so hits
and add them to the cache.  It should return the number
of hits found or undef when there are no more hits.

Internally, C<native_retrieve_some> typically
will parse the HTML, extract the links and descriptions,
then find the ``next'' button and save the URL.
See the code for the AltaVista implementation for an example.

C<native_setup_search> is invoked before the search.
It is passed a single argument:  the escaped, native version
of the query.

The front- and back-ends share a single object (a hash)
The back-end can change any hash element beginning with underscore,
and C<{response}> (an C<HTTP::Response> code) and C<{cache}>
(the array of C<WWW::SearchResult> objects caching all results).

If you implement a new back-end, please let the authors know.


=head1 BUGS AND DESIRED FEATURES

The bugs are there for you to find (some people call them Easter Eggs).

Desired features:

=over 4

=item A portable query language.
A portable language would easily allow you to
move queries easily between different search engines.
A  query abstraction is non-trivial
and won't be done anytime soon at ISI.
If you want to take a shot at it, please let me know.

=back


=head1 AUTHOR

C<WWW::Search> is written by John Heidemann, <johnh@isi.edu>.

Back-ends and applications for WWW::Search have been done by 
John Heidemann,
Wm. L. Scheding,
Cesare Feroldi de Rosa,
and
GLen Pringle.


=head1 COPYRIGHT

Copyright (c) 1996 University of Southern California.
All rights reserved.                                            
                                                               
Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation, advertising
materials, and other materials related to such distribution and use
acknowledge that the software was developed by the University of
Southern California, Information Sciences Institute.  The name of the
University may not be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut
#'


# make warnings go away
if (0) {
    my($x);
    $x = %URI::Escape::escapes;
    $x = $VERSION;
};


1;
