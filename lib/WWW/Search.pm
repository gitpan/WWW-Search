#!/usr/local/bin/perl -w

#
# Search.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Search.pm,v 1.23 1996/11/07 00:18:42 johnh Exp $
#
# A complete copyright notice appears at the end of this file.
# 


package WWW::Search;

=head1 NAME

WWW::Search - Virtual base class for WWW searches


=head1 DESCRIPTION

This class is the parent for all access method supported by the
C<WWW::Search> library.  This library implements a Perl API
to web-based search engines.

Current search engines supported include
AltaVista (both web and Usenet searches),
Lycos,
and HotBot.

Search results are limited and there is a pause between each request 
for results to avoid overloading either the client or the server.

=head2 Sample program

Using the library should be straightforward:
Here's a sample program:

    my($search) = new WWW::Search::AltaVista;
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


=head1 METHODS AND FUNCTIONS

=cut
#'

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw(escape_query unescape_query);
$VERSION = 1.005;
require LWP::MemberMixin;
@ISA = qw(Exporter LWP::MemberMixin);
require LWP::UserAgent;
#require LWP::RobotUA;

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

sub new
{ 
    my($class, $engine) = @_;

    $engine = $default_engine if (!defined($engine));
    # Load the engine, if necessary.
    my($subclass) = "${class}::$engine";
    if (!defined(&$subclass)) {
	eval "use $subclass";
	Carp::croak("unknown search engine back-end $engine") if ($@);
    };

    my $self = bless {
	engine => $engine,
	state => $SEARCH_BEFORE,
	next_to_return => 0,
	maximum_to_retrieve => 500,  # both pages and hits
	number_retrieved => 0,
	requests_made => 0,
	interrequest_delay => 0.25,
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

The hash of options following the query string is optional.  Both the
query string and the hash of options are interpreted in
search-engine-specific manner.

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
}
sub approximate_result_count { return shift->_elem('approx_count', @_); }


=head2 results

Return all the results of a query as a reference to array 
of SearchResult objects.

Example:
    @results = $search->results();
    foreach $result (@results) {
        print $result->url(), "\n";
    };

=cut

sub results
{
    my($self) = shift;
    Carp::croak "search not yet specified"
	if (!defined($self->{'native_query'}));
    while ($self->retrieve_some()) {
	# leave them in the cache
    };
    return @{$self->{cache}};
}

=head2 next_result

Return each result of a query as a SearchResult object.

Example:
    while ($result = $search->next_result()) {
	print $result->url(), "\n";
    };

=cut
sub next_result
{
    my($self) = shift;
    Carp::croak "search not yet specified"
	if (!defined($self->{'native_query'}));
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

The maximum number of hits to return (approximately).
Queries resulting in more than this many hits will return
the first hits, up to this limit.

Defaults to 500.

Example:
    $max = $seach->maximum_to_retrieve(100);

=cut
sub title { return shift->_elem('maximum_to_retrieve', @_); }


=head2 escape_query

Escape a query.
Before queries are made special characters must be escaped
so that a proper URL can be formed.

This is like escaping a URL
but "+" is a protected character
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
    # Default unsafe characters except for space. (RFC1738 section 2.2)
    $text =~ s/([+\x00-\x1f"#%;<>?{}|\\\\^~`\[\]\x7F-\xFF])/$URI::Escape::escapes{$1}/g; #"
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


=head2 setup_user_agent (PRIVATE, NOT A METHOD)

This internal routine does setup for a user-agent
for dervived classes that use the web.

=cut

sub setup_user_agent
{
    #
    # Sigh.  We should use RobotUA,
    # but all search engines prohibit all robots from making
    # queries (presumably to avoid search-engine overload).
    #
    my($ua) = new LWP::UserAgent;
    $ua->agent('WWW::Search/johnh@isi.edu');
#    $ua->delay(1/60.0);   # inter-page delay in minutes
    return $ua;
}

=head2 user_agent_delay (PRIVATE)

Derived classes should call this between requests to remote
servers to avoid overloading them with many, fast back-to-back requests.

=cut
sub user_agent_delay {
    my($self) = @_;
    # sleep for a qarter second
    select(undef, undef, undef, $self->{interrequest_delay});
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
    if ($self->{number_retrieved} > $self->{maximum_to_retrieve}) {
        $self->{state} = $SEARCH_DONE;
	return;
    };
    if ($self->{requests_made} > $self->{maximum_to_retrieve}) {
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


=head1 AUTHOR

C<WWW::Search> is written by John Heidemann, <johnh@isi.edu>.

Back-ends and applications for WWW::Search have been done by 
John Heidemann,
Wm. L. Scheding,
and others.


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


# make warnings go away
if (0) {
    my($x);
    $x = %URI::Escape::escapes;
    $x = $VERSION;
};


1;
