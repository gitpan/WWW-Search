# Search.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Search.pm,v 1.57 2001/07/05 13:34:55 mthurn Exp mthurn $
#
# A complete copyright notice appears at the end of this file.

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

See README for a list of search engines currently supported, and for a
lot of interesting high-level information about this distribution.

Search results can be limited, and there is a pause between each
request to avoid overloading either the client or the server.

=head2 Sample program

Here is a sample program:

    my $search = new WWW::Search('AltaVista');
    $search->native_query(WWW::Search::escape_query($query));
    while (my $result = $search->next_result())
      {
      print $result->url, "\n";
      }

Results are objects of type C<WWW::SearchResult>
(see L<WWW::SearchResult> for details).
Note that different backends support different result fields.
All backends are required to support title and url.


=head1 SEE ALSO

For specific search engines, see L<WWW::Search::TheEngineName>
(replacing TheEngineName with a particular search engine).

For details about the results of a search,
see L<WWW::SearchResult>.


=head1 METHODS AND FUNCTIONS

Methods and functions marked as PRIVATE are in general only useful to
backend programmers.

=cut

#####################################################################

package WWW::Search;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw(escape_query unescape_query generic_option strip_tags @ENGINES_WORKING);
$VERSION = '2.23';
$MAINTAINER = 'Martin Thurn <mthurn@tasc.com>';
require LWP::MemberMixin;
@ISA = qw(Exporter LWP::MemberMixin);

use Carp ();
use Data::Dumper;  # for debugging only
use HTTP::Cookies;
use HTTP::Request;
use HTTP::Response;
use HTTP::Status;
use LWP::RobotUA;
use LWP::UserAgent;
use URI::Escape;

# internal
my ($SEARCH_BEFORE, $SEARCH_UNDERWAY, $SEARCH_DONE) = (1..10);

=head2 new

To create a new WWW::Search, call

    $search = new WWW::Search('SearchEngineName');

where SearchEngineName is replaced with a particular search engine.
For example:

    $search = new WWW::Search('Google');

If no search engine is specified a default (currently 'AltaVista')
will be chosen for you.
The next step is usually:

    $search->native_query('search-engine-specific+query+string');

=cut


# the default (not currently more configurable :-< )
$default_engine = 'AltaVista';
$default_agent_name = "WWW::Search/$VERSION";
$default_agent_e_mail = 'MartinThurn@iname.com';

sub new
  { 
  my $class = shift;
  my $engine = shift;
  # Remaining arguments will become hash args

  $engine = $default_engine if (!defined($engine));
  # Load the engine, if necessary.
  my $subclass = "${class}::$engine";
  if (!defined(&$subclass)) 
    {
    eval "use $subclass";
    Carp::croak("unknown search engine backend $engine ($@)") if ($@);
    } # if

  my $self = bless {
                    engine => $engine,
                    maximum_to_retrieve => 500,  # both pages and hits
                    interrequest_delay => 0.25,  # in seconds
                    agent_name => $default_agent_name,
                    agent_e_mail => $default_agent_e_mail,
                    http_proxy => undef,
                    http_proxy_user => undef,
                    http_proxy_pwd => undef,
                    timeout => 60,
                    debug => 0,
                    search_from_file => undef,
                    search_to_file => undef,
                    search_to_file_index => 0,
                    @_,
                    # variable initialization goes here
                   }, $subclass;
  $self->reset_search();
  return $self;
  } # new

=head2 reset_search (PRIVATE)

Resets internal data structures to start over with a new search.

=cut

sub reset_search
  {
  my $self = shift;
  print STDERR " + reset_search(",$self->{'native_query'},")\n" if $self->{debug};
  $self->{'cache'} = ();
  $self->{'debug'} = 0;
  $self->{'native_query'} = '';
  $self->{'next_to_retrieve'} = 1;
  $self->{'next_to_return'} = 0;
  $self->{'number_retrieved'} = 0;
  $self->{'requests_made'} = 0;
  $self->{'state'} = $SEARCH_BEFORE;
  $self->{'_next_url'} = '';
  $self->_elem('approx_count', 0);
  # This method is called by native_query().  native_query() is called
  # either by gui_query() or by the user.  In the case that
  # gui_query() was called, we do NOT want to clear out the _options
  # hash.  For now, I implement a pretty ugly hack to make this work:
  if (caller(2))
    {
    my @as = caller(2);
    if (1 < scalar(@as))
      {
      # print STDERR " in reset_search(), as is (", join(',', @as), ")\n";
      return if $as[3] =~ m/gui_query/;
      } # if
    } # if
  $self->{_options} = ();
  } # reset_search

=head2 version

Returns the value of the $VERSION variable of the backend engine, or
$WWW::Search::VERSION if the backend does not contain $VERSION.

=cut

sub version
  {
  my $self = shift;
  my $iVersion = eval '$'.ref($self).'::VERSION';
  # print STDERR " + iVersion = >>>$iVersion<<<\n";
  $iVersion ||= $VERSION;
  return $iVersion;
  } # version

=head2 maintainer

Returns the value of the $MAINTAINER variable of the backend engine,
or $WWW::Search::MAINTAINER if the backend does not contain
$MAINTAINER.

=cut

sub maintainer
  {
  my $self = shift;
  my $sMaintainer = eval '$'.ref($self).'::MAINTAINER';
  # print STDERR " + sMaintainer = >>>$sMaintainer<<<\n";
  $sMaintainer ||= $MAINTAINER;
  return $sMaintainer;
  } # maintainer

=head2 gui_query

Specify a query to the current search object;
the query will be performed with the engine's default options,
as if it were typed by a user in a browser window.

The query must be escaped; call L<&WWW::Search::escape_query> to escape
a plain query.  See C<native_query> below for more information.

Currently, this feature is supported by only a few backends;
consult the documentation for each backend to see if it is implemented.

=cut

sub gui_query
  {
  # This function is a stub to prevent runtime errors.  This function
  # should be defined in each backend as appropriate.  See Yahoo.pm in
  # the WWW-Search-Yahoo distribution for an example of how to
  # implement it.
  my $self = shift;
  return $self->native_query(@_);
  } # gui_query


=head2 native_query

Specify a query (and optional options) to the current search object.
Previous query (if any) and its cached results (if any) will be thrown away.
The option values and the query must be escaped; call L<WWW::Search::escape_query()>
to escape a string.
The search process is not actually begun until C<results> or
C<next_result> is called (lazy!), so native_query does not return anything.

Example:

  $search->native_query('search-engine-specific+escaped+query+string',
                        { option1 => 'able', option2 => 'baker' } );

The hash of options following the query string is optional.  
The query string is backend-specific.
There are two kinds of options:
options specific to the backend,
and generic options applicable to multiple backends.

Generic options all begin with 'search_'.
Currently a few are supported:

=over 4

=item search_url

Specifies the base URL for the search engine.

=item search_debug

Enables backend debugging.  The default is 0 (no debugging).

=item search_parse_debug

Enables backend parser debugging.  The default is 0 (no debugging).

=item search_method

Specifies the HTTP method (C<GET> or C<POST>) for HTTP-based queries.
The default is GET

=item search_to_file FILE

Causes the search results to be saved in a set of files 
prefixed by FILE.
(Used internally by the test-suite, not intended for general use.)

=item search_from_file FILE

Reads a search from a set of files prefixed by FILE.
(Used internally by the test-suite, not intended for general use.)

=back

Some backends may not implement these generic options,
but any which do implement them must provide these semantics.

Backend-specific options are described
in the documentation for each backend.
In most cases the options and their values are packed together to create the query portion of
the final URL.

Details about how the search string and option hash are interpreted
might be found in the search-engine-specific manual pages
(WWW::Search::SearchEngineName).

After C<native_query>, the next step is usually:

    while ($result = $search->next_result())
      {
      # do_something;
      }

=cut

sub native_query
  {
  my $self = shift;
  print STDERR " + native_query($_[0])\n" if $self->{debug};
  # return $self->_elem('native_query', @_) if ($#_ != 1);
  $self->reset_search();
  $self->{'native_query'} = $_[0];
  $self->{'native_options'} = $_[1];
  # promote generic options
  my $opts_ref = $_[1];
  foreach my $sKey (keys %$opts_ref)
    {
    if (generic_option($sKey))
      {
      # print STDERR " +   promoting $sKey to $self\n";
      $self->{$sKey} = $opts_ref->{$sKey};
      # delete $opts_ref->{$sKey};
      } # if
    } # foreach
  } # native_query

=head2 cookie_jar

Call this method (anytime before asking for results) if you want to
communicate cookie data with the search engine.  Takes one argument,
either a filename or an HTTP::Cookies object.  If you give a filename,
WWW::Search will attempt to read/store cookies there (by in turn
passing the filename to HTTP::Cookies::new).

  $oSearch->cookie_jar('/tmp/my_cookies');

If you give an HTTP::Cookies object, it is up to you to save the
cookies if/when you wish.

  use HTTP::Cookies;
  my $oJar = HTTP::Cookies->new(...);
  $oSearch->cookie_jar($oJar);

=cut

sub cookie_jar
  {
  my $self = shift;
  my $arg = shift;
  if (ref($arg) eq 'HTTP::Cookies')
    {
    $self->{'_cookie_jar'} = $arg;
    $self->{'_cookie_jar_we_save'} = 0;
    }
  elsif (! ref($arg))
    {
    # Assume that $arg is a file name:
    $self->{'_cookie_jar'} = HTTP::Cookies->new(
                                               'file' => $arg,
                                               'autosave' => 1,
                                               'ignore_discard' => 1,
                                               );
    $self->{'_cookie_jar'}->load;
    $self->{'_cookie_jar_we_save'} = 1;
    # print STDERR " + WWW::Search just loaded cookies from $arg\n";
    }
  else
    {
    Carp::carp "argument to WWW::Search::cookie_jar() must be HTTP::Cookies or scalar";
    }
  } # cookie_jar


=head2 date_from

Set/get the start date for limiting the query by a date range.  See
the documentation for each backend to find out if date ranges are
supported for each search engine.

=head2 date_to

Set/get the end date for limiting the query by a date range.  See the
documentation for each backend to find out if date ranges are
supported for each search engine.

=cut

sub date_from
  {
  return shift->_elem('date_from', @_);
  } # date_from

sub date_to
  {
  return shift->_elem('date_to', @_);
  } # date_from


=head2 http_proxy

Set-up an HTTP proxy
(for connections from behind a firewall).

This routine should be called before calling any of the result
functions (next_result or results).

Example:

    $search->http_proxy("http://gateway:8080");

=cut

sub http_proxy { return shift->_elem('http_proxy', @_); }


=head2 http_proxy_user, http_proxy_pwd

Set/get HTTP proxy authentication data.

These routines set/get username and password used in proxy
authentication.  Authentication is performed only if proxy, username
and password are available.

Example:

    $search->http_proxy_user("myuser");
    $search->http_proxy_pwd("mypassword");
    $search->http_proxy_user(undef);   # Example for no authentication

    $username = $search->http_proxy_user();

=cut

sub http_proxy_user
  {
  my $obj = shift;
  @_ ? $obj->{http_proxy_user} = shift() : $obj->{http_proxy_user};
  }

sub http_proxy_pwd
  {
  my $obj = shift;
  @_ ? $obj->{http_proxy_pwd} = shift() : $obj->{http_proxy_pwd};
  }


=head2 is_http_proxy_auth_data (PRIVATE)

Checks if authentication data (proxy name, username, and password) are available.
In this case proxy authentication is performed.

=cut

sub is_http_proxy_auth_data
  {
  my $self = shift;
  return (
          defined($self->http_proxy()) &&
          defined($self->http_proxy_user()) &&
          defined($self->http_proxy_pwd())
         );
  }


=head2 approximate_result_count

Some backends indicate how many hits they have found.
Typically this is an approximate value.

=cut

sub approximate_result_count
  {
  my $self = shift;
  # prime the pump:
  $self->retrieve_some() if ($self->{'state'} == $SEARCH_BEFORE);
  return $self->_elem('approx_count', @_);
  } # approximate_result_count


=head2 results

Return all the results of a query as an array of SearchResult objects.

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
  my $self = shift;
  print STDERR " + results(",$self->{'native_query'},")\n" if $self->{debug};
  Carp::croak "query string is not defined" if (!defined($self->{'native_query'}));
  Carp::croak "query string is empty" unless ($self->{'native_query'} ne '');
  # Put all the SearchResults into the cache:
  1 while ($self->retrieve_some());
  my $iMax = scalar(@{$self->{cache}});
  $iMax = $self->{maximum_to_retrieve} if ($self->{maximum_to_retrieve} < $iMax);
  return @{$self->{cache}}[0..$iMax-1];
  } # results

=head2 next_result

Call this method repeatedly to return each result of a query as a
SearchResult object.  Example:

    while ($result = $search->next_result())
      {
      print $result->url(), "\n";
      }

On error, next_result() will return undef and set C<response()>
to the HTTP response code.

=cut

sub next_result
  {
  my $self = shift;
  Carp::croak "search not yet specified" if (!defined($self->{'native_query'}));
  return undef if ($self->{next_to_return} >= $self->{maximum_to_retrieve});
  while (1)
    {
    if ($self->{next_to_return} <= $#{$self->{cache}}) 
      {
      # The cache already contains the desired element; return it:
      my $i = ($self->{next_to_return})++;
      return ${$self->{cache}}[$i];
      }
    # If we get here, then the desired element is beyond the end of
    # the cache.  
    if ($self->{state} == $SEARCH_DONE) 
      {
      # There are no more results to be gotten; fail & bail:
      return undef;
      }
    # Get some more results into the cache:
    $self->retrieve_some();
    # Go back and try again:
    } # while infinite
  } # next_result


=head2 response

Returns the an HTTP::Response object which resulted from the
most-recently-sent query (see L<HTTP::Response>).  If the query
returns no results (i.e. $search->results is C<undef>), errors can
be reported like this:

    my $response = $search->response();
    if ($response->is_success) {
	print "normal end of result list\n";
    } else {
	print "error:  " . $response->as_string() . "\n";
    }

Note to backend authors: even if the backend does not involve the web,
it should return an HTTP::Response object.

=cut

sub response
  {
  my $self = shift;
  $self->{response} ||= new HTTP::Response(RC_OK);
  return $self->{response};
  } # response


=head2 seek_result($offset)

Set which result C<next_result> should be returned next time
next_result() is called.  Results are zero-indexed.

The only guaranteed valid offset is 0,
which will replay the results from the beginning.
In particular, seeking past the end of the current cached
results probably will not do what you might think it should.

Results are cached, so this does not re-issue the query
or cause IO (unless you go off the end of the results).
To re-do the query, create a new search object.

Example:

    $search->seek_result(0);

=cut

sub seek_result
  {
  my ($self, $desired) = @_;
  my $old = $self->{next_to_return};
  $self->{next_to_return} = $desired if (defined($desired) and (0 <= $desired));
  return $old;
  } # seek_result


=head2 maximum_to_retrieve

Set the maximum number of hits to return.
Queries resulting in more than this many hits will return
the first hits, up to this limit.
Although this specifies a maximum limit,
search engines might return less than this number.

Defaults to 500.

Example:
    $max = $search->maximum_to_retrieve(100);

You can also spell this method "maximum_to_return".

=cut

sub maximum_to_retrieve { return shift->_elem('maximum_to_retrieve', @_); }
sub maximum_to_return { return shift->_elem('maximum_to_retrieve', @_); }


=head2 timeout

The maximum length of time any portion of the query should take,
in seconds.

Defaults to 60.

Example:
    $search->timeout(120);

=cut

sub timeout { return shift->_elem('timeout', @_); }


=head2 submit

This method can be used to submit URLs to the search engines for indexing.
Consult the documentation for each backend to find out if it is implemented there,
and if so what the arguments are.

Returns an HTTP::Response object describing the result of the submission request.
Consult the documentation for each backend to find out the meaning of the response.

=cut

sub submit
  {
  return new HTTP::Response(788, 'Sorry, this backend does not support the submit() method.');
  } # submit


=head2 opaque

This function provides an application a place to store
one opaque data element (or many, via a Perl reference).
This facility is useful to (for example),
maintain client-specific information in each active query
when you have multiple concurrent queries.

=cut

sub opaque { return shift->_elem('opaque', @_); }


=head2 escape_query

Escape a query.
Before queries are sent to the internet, special characters must be escaped
so that a proper URL can be formed.
This is like escaping a URL,
but all non-alphanumeric characters are escaped and
and spaces are converted to "+"s.

Example:
    $escaped = WWW::Search::escape_query('+hi +mom');

    (Returns "%2Bhi+%2Bmom").

See also C<unescape_query>.
NOTE that this is not a method, it is a plain function.

=cut

sub escape_query
  {
  my $text = join(' ', @_);
  $text ||= '';
  # print STDERR " +   escape_query($text)\n";
  $text =~ s/([^ A-Za-z0-9])/$URI::Escape::escapes{$1}/g; #"
  # print STDERR " +   escape_query($text)\n";
  $text =~ s/ /+/g;
  # print STDERR " +   escape_query($text)\n";
  return $text;
  } # escape_query

=head2 unescape_query

Unescape a query.
See C<escape_query> for details.

Example:
    $unescaped = WWW::Search::unescape_query('%22hi+mom%22');

    (Returns '"hi mom"').

NOTE that this is not a method, it is a plain function.

=cut

sub unescape_query {
    # code stolen from URI::Escape.pm.
    my @copy = @_;
    for (@copy) {
	s/\+/ /g;
	s/%([\dA-Fa-f]{2})/chr(hex($1))/eg;
    }
    return wantarray ? @copy : $copy[0];
}

=head2 strip_tags

Given a string, returns a copy of that string with HTML tags removed.
This should be used by each backend as they insert the title and
description values into the SearchResults.

NOTE that this is not a method, it is a plain function.

=cut

sub strip_tags
  {
  # This is not a method; there is no $self
  my @as = @_;
  foreach (@as)
    {
    # We assume for now that we will not be encountering tags with
    # embedded '>' characters!
    s/\074.+?\076//g;
    s/&nbsp;/ /g;
    s/&lt;/\074/g;
    s/&gt;/\076/g;
    s/&quot;/\042/g;
    } # foreach
  return wantarray ? @as : shift @as;
  } # strip_tags

=head2 hash_to_cgi_string (PRIVATE) (DEPRECATED)

Deprecated.

Given a reference to a hash of string => string, constructs a CGI
parameter string that looks like 'key1=value1&key2=value2'.

At one time, for testing purposes, we asked backends to use this
function rather than piecing the URL together by hand, to ensure that
URLs are identical across platforms and software versions.  But this
is no longer necessary.

Example:

    $self->{_options} = {
                         'opt3' => 'val3',
                         'search_url' => 'http://www.deja.com/dnquery.xp',
                         'opt1' => 'val1',
                         'QRY' => $native_query,
                         'opt2' => 'val2',
                        };
    $self->{_next_url} = $self->{_options}{'search_url'} .'?'.
                         $self->hash_to_cgi_string($self->{_options});

=cut

sub hash_to_cgi_string
  {
  my $self = shift;
  # Because of the design of our test suite, we need our generated
  # URLs to be identical on all systems, all versions of perl.  Ergo
  # we must explicitly control the order in which our CGI parameter
  # strings are cobbled together.  For now, I assume sorting the hash
  # keys will suffice.
  my $rh = shift;
  my $ret = '';
  foreach my $key (sort keys %$rh)
    {
    # printf STDERR "option: $key is " . $rh->{$key} . "\n";
    next if generic_option($key);
    # If we want to let the user delete options, uncomment the next
    # line. (They can still blank them out, which may or may not have
    # the same effect):

    # next unless $rh->{$key} ne '';

    $ret .= $key .'='. $rh->{$key} .'&';
    }
  # Remove the trailing '&':
  chop $ret;
  return $ret;
  } # hash_to_cgi_string


=head2 user_agent($NON_ROBOT) (PRIVATE)

This internal routine creates a user-agent for derived classes that
query the web.  If non-false argument $non_robot is given, a normal
user-agent (rather than a robot-style user-agent) is used.

If a backend needs the low-level LWP::UserAgent or LWP::RobotUA to
have a particular name, $oSearch->{'agent_name'} (and possibly
$oSearch->{'agent_e_mail'}) should be set to the desired values before
calling $oSearch->user_agent():

  $oSearch = new WWW::Search('NewBackend');
  $oSearch->{'agent_e_mail'} = $oSearch->{'agent_name'};
  $oSearch->{'agent_name'} = 'Mozilla/5.5';
  $oSearch->user_agent('non-robot');

Backends should use robot-style user-agents whenever possible.

=cut

sub user_agent
  {
  my ($self, $non_robot) = @_;
  $non_robot ||= '';
  my $ua;
  if ($non_robot ne '')
    {
    $ua = new LWP::UserAgent;
    $ua->agent($self->{'agent_name'});
    $ua->from($self->{'agent_e_mail'});
    }
  else
    {
    $ua = new LWP::RobotUA($self->{'agent_name'}, $self->{'agent_e_mail'});
    $ua->delay($self->{'interrequest_delay'}/60.0);
    }
  $ua->timeout($self->{'timeout'});
  $ua->proxy('http', $self->{'http_proxy'}) if (defined($self->{'http_proxy'}));
  $self->{'user_agent'} = $ua;
  } # user_agent


=head2 http_referer (PRIVATE)

Get / set the value of the HTTP_REFERER variable for this search object.
Some search engines might only accept requests that originated at some specific previous page.
This method lets backend authors "fake" the previous page.
Call this method before calling http_request.

  $oSearch->http_referer('http://prev.engine.com/wherever/setup.html');
  $oResponse = $oSearch->http_request('GET', $url);

=cut

sub http_referer { return shift->_elem('_http_referer', @_); }


=head2 http_request($method, $url)

Return the response from an http request, handling debugging.
Requires that user_agent already be set up, if needed.
Requires that http_referer already be set up, if needed.

=cut

sub http_request
  {
  my $self = shift;
  my ($method, $url) = @_;
  my $response;
  if ($self->{search_from_file})
    {
    $response = $self->http_request_from_file($url);
    }
  else
    {
    # fetch it
    my $request;
    if ($method eq 'POST')
      {
      my $uri_url = new URI::URL($url);
      my $equery = $uri_url->equery;
      $uri_url->equery(undef);   # we will handle the query ourselves
      $request = new HTTP::Request($method, $uri_url->abs());
      $request->header('Content-Type', 'application/x-www-form-urlencoded');
      $request->header('Content-Length', length $equery);
      $request->content($equery);
      }
    else
      {
      $request = new HTTP::Request($method, $url);
      }

    if ($self->is_http_proxy_auth_data())
      {
      $request->proxy_authorization_basic($self->http_proxy_user(),
                                          $self->http_proxy_pwd());
      }

    $self->{'_cookie_jar'}->add_cookie_header($request) if ref($self->{'_cookie_jar'});
    # print STDERR " + the request with cookies is >>>", $request->as_string, "<<<\n";

    if ($self->{'_http_referer'} && ($self->{'_http_referer'} ne ''))
      {
      my $s = uri_escape($self->{'_http_referer'});
      # print STDERR " +    referer($s), ref(s) = ", ref($s), "\n";
      $s = $s->as_string if ref($s) =~ m!URI!;
      $request->referer($s);
      } # if referer

    my $ua = $self->{'user_agent'};
    $response = $ua->request($request);

    if (ref($self->{'_cookie_jar'}))
      {
      $self->{'_cookie_jar'}->extract_cookies($response);
      $self->{'_cookie_jar'}->save if $self->{'_cookie_jar_we_save'};
      # print STDERR " + WWW::Search just extracted cookies\n";
      # print STDERR $self->{'_cookie_jar'}->as_string;
      # print STDERR Dumper($self->{'_cookie_jar'});
      }

    if ($self->{'search_to_file'} && $response->is_success)
      {
      $self->http_request_to_file($url, $data, $response);
      } # if
    } # if not from_file
  return $response;
  } # http_request

sub http_request_get_filename {
    my $self = shift;
    my $fn;
    # filename?
    if (!defined($self->{search_filename})) {
	$fn = $self->{search_from_file};
	$fn = $self->{search_to_file} if (!defined($fn));
	$self->{search_filename} = WWW::Search::unescape_query($fn);
    }
    $fn = $self->{search_filename};
    die "$0: bogus filename.\n" if (!defined($fn));
    return $fn;
}

sub http_request_from_file {
    my $self = shift;
    my ($url) = @_;

    my $fn = $self->http_request_get_filename();

    # read index?
    if (!defined($self->{search_from_file_hash})) {
	open(TABLE, "<$fn") || die "$0: open $fn failed.\n";
	my $i = 0;
	while (<TABLE>) {
	    chomp;
	    $self->{search_from_file_hash}{$_} = $i;
	    # print STDERR "$0: file index: $i <$_>\n";
	    $i++;
	};
	close TABLE;
    };

    # read file
    my $i = $self->{search_from_file_hash}{$url};
    if (defined($i)) {
	# print STDERR "$0: saved request <$url> found in $fn.$i\n";
	# read the data
	open(FILE, "<$fn.$i") || die "$0: open $fn.$i\n";
	my $d = '';
	while (<FILE>) {
	    $d .= $_;
	};
	close FILE;
	# make up the response
	my $r = new HTTP::Response(RC_OK);
	$r->content($d);
	return $r;
    } else {
	print STDERR "$0: saved request <$url> not found.\n";
	my $r = new HTTP::Response(RC_NOT_FOUND);
	return $r;
    };
}

sub http_request_to_file {
    my $self = shift;
    my $response = pop;
    my ($url) = @_;

    my $fn = $self->http_request_get_filename();

    unlink($fn)
        if ($self->{search_to_file_index} == 0);
    open(TABLE, ">>$fn") || die "$0: open $fn\n";
    print TABLE "$url\n";
    close TABLE;
    my $i = ($self->{search_to_file_index})++;
    open (FILE, ">$fn.$i") || die "$0: open $fn.$i\n";
    print FILE $response->content();
    close FILE;
}

=head2 next_url (PRIVATE)

Get or set the URL for the next backend request.  This can be used to
save the WWW::Search state between sessions (e.g. if you are showing
pages of results to the user in a web browser).  Before closing down a
session, save the value of next_url:

  ...
  $oSearch->maximum_to_return(10);
  while ($oSearch->next_result) { ... }
  my $urlSave = $oSearch->next_url;

Then, when you start up the next session (e.g. after the user clicks
your "next" button), restore this value before calling for the results:

  $oSearch->native_query(...);
  $oSearch->next_url($urlSave);
  $oSearch->maximum_to_return(20);
  while ($oSearch->next_result) { ... }

WARNING: It is entirely up to you to keep your interface in sync with
the number of hits per page being returned from the backend.  And, we
make no guarantees whether this method will work for any given
backend.  (Their caching scheme might not enable you to jump into the
middle of a list of search results, for example.)

=cut

sub next_url { return shift->_elem('_next_url', @_); }


=head2 split_lines (PRIVATE)

This internal routine splits data (typically the result of the web
page retrieval) into lines in a way that is OS independent.  If the
first argument is a reference to an array, that array is taken to be a
list of possible delimiters for this split.  For example, Yahoo.pm
uses <p> and <dd><li> as "line" delimiters for convenience.

=cut

sub split_lines
  {
  # This probably fails on an EBCDIC box where input is in text mode.
  # Too bad Macs do not just use binmode like Windows boxen.
  my $self = shift;
  my $s = shift;
  my $patt = '\015?\012';
  if (ref($s))
    {
    $patt = '('. $patt;
    foreach (@$s)
      {
      $patt .= "|$_";
      } # foreach
    $patt .= ')';
    # print STDERR " +     patt is >>>$patt<<<\n";
    $s = shift;
    } # if
  return split(/$patt/i, $s);
  # If we require perl 5.005, this can be done by:
  # use Socket qw(:crlf :DEFAULT);
  # split(/$CR?$LF/,$_[0])
  } # split_lines

=head2 generic_option (PRIVATE)

This internal routine checks if an option
is generic or backend specific.
Currently all generic options begin with 'search_'.
This routine is not a method.

=cut

sub generic_option 
{
    my ($option) = @_;
    return ($option =~ /^search_/);
}



=head2 setup_search (PRIVATE)

This internal routine does generic Search setup.
It calls C<native_setup_search> to do backend specific setup.

=cut


sub setup_search
  {
  my ($self) = @_;
  print STDERR " + setup_search(",$self->{'native_query'},")\n" if $self->{debug};
  $self->{cache} = ();
  $self->{next_to_retrieve} = 1;
  $self->{number_retrieved} = 0;
  $self->{state} = $SEARCH_UNDERWAY;
  # $self->{_options} = ();
  $self->native_setup_search($self->{'native_query'}, $self->{'native_options'});
  } # setup_search


=head2 user_agent_delay (PRIVATE)

Derived classes should call this between requests to remote
servers to avoid overloading them with many, fast back-to-back requests.

=cut
sub user_agent_delay {
    my ($self) = @_;
    # sleep for a quarter second
    select(undef, undef, undef, $self->{interrequest_delay})
	 if ($self->{robot_p});
}

=head2 absurl (PRIVATE)

An internal routine to convert a relative URL into a absolute URL.  It
takes two arguments, the 'base' url (usually the search engine CGI
URL) and the URL to be converted.  Returns a URI or URI::URL object
(whichever is being used by HTTP on your system).

=cut

sub absurl
  {
  my ($self, $base, $url) = @_;
  #$url =~ s,^http:/([^/]),/$1,; #bogus sfgate URL
  my $link = $HTTP::URI_CLASS->new_abs($url, $base);
  return($link);
  } # absurl


=head2 retrieve_some (PRIVATE)

An internal routine to interface with C<native_retrieve_some>.
Checks for overflow.

=cut

sub retrieve_some
  {
  my $self = shift;
  print STDERR " + retrieve_some(",$self->{'native_query'},")\n" if $self->{debug};
  return undef if ($self->{state} == $SEARCH_DONE);
  # assume that caller has verified defined($self->{'native_query'}).
  $self->setup_search() if ($self->{state} == $SEARCH_BEFORE);
  
  # got enough already?
  if ($self->{number_retrieved} >= $self->{'maximum_to_retrieve'})
    {
    $self->{state} = $SEARCH_DONE;
    return;
    }
  if ($self->{requests_made} > $self->{'maximum_to_retrieve'}) {
    $self->{state} = $SEARCH_DONE;
    return;
    }
  
  # do it
  my $res = $self->native_retrieve_some();
  print STDERR " +   native_retrieve_some() returned $res\n" if $self->{debug};
  $self->{requests_made}++;
  $self->{number_retrieved} += $res if (defined($res));
  $self->{state} = $SEARCH_DONE if (!defined($res) || $res == 0);
  return $res;
  } # retrieve_some


=head2 test_cases (deprecated)

Deprecated.

Returns the value of the $TEST_CASES variable of the backend engine.

=cut

sub test_cases
  {
  my $self = shift;
  return eval '$'.ref($self).'::TEST_CASES';
  } # test_cases

=head1 IMPLEMENTING NEW BACKENDS

C<WWW::Search> supports backends to separate search engines.
Each backend is implemented as a subclass of C<WWW::Search>.
L<WWW::Search::AltaVista> provides a good sample backend.

A backend must have the two routines
C<native_retrieve_some> and C<native_setup_search>.

C<native_retrieve_some> is the core of a backend.
It will be called periodically to fetch URLs.
It should retrieve several hits from the search service
and add them to the cache.  It should return the number
of hits found, or undef when there are no more hits.

Internally, C<native_retrieve_some> typically sends an HTTP request to
the search service, parse the HTML, extract the links and
descriptions, then save the URL for the next page of results.  See the
code for the AltaVista implementation for an example.

C<native_setup_search> is invoked before the search.
It is passed a single argument:  the escaped, native version
of the query.

The front- and backends share a single object (a hash).
The backend can change any hash element beginning with underscore,
and C<{response}> (an C<HTTP::Response> code) and C<{cache}>
(the array of C<WWW::SearchResult> objects caching all results).
Again, look at one of the existing web search backends as an example.

If you implement a new backend, please let the authors know.


=head1 BUGS AND DESIRED FEATURES

The bugs are there for you to find (some people call them Easter Eggs).

Desired features:

=over 4

=item A portable query language.

A portable language would easily allow you to move queries easily
between different search engines.  A query abstraction is non-trivial
and unfortunately will not be done anytime soon by the current
maintainers.  If you want to take a shot at it, please let me know.

=back


=head1 AUTHOR

C<WWW::Search> was written by John Heidemann, E<johnh@isi.edu>.
C<WWW::Search> is currently maintained by Martin Thurn, E<MartinThurn@iname.com>.

backends and applications for WWW::Search were originally written by
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


@ENGINES_WORKING = qw(
                      Crawler
                      Excite::News
                      Fireball
                      FolioViews
                      HotFiles
                      MetaCrawler
                      Metapedia
                      NetFind
                      Null
                      SFgate
                      VoilaFr
                     );

1;
