#!/usr/local/bin/perl -w

#####################################################
# GoTo.pm
# by Jim Smyser
# Copyright (C) 1996-1999 by Jim Smyser & USC/ISI
# $Id: GoTo.pm,v 1.7 1999/11/05 19:16:05 mthurn Exp $
######################################################

package WWW::Search::GoTo;

=head1 NAME

WWW::Search::GoTo - class for searching GoTo.com 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('GoTo');


=head1 DESCRIPTION

This class is an GoTo specialization of WWW::Search.
It handles making and interpreting GoTo searches
F<www-GoTo.com>.

Nothing special about GoTo: no search options. It is much like
Google in that it attempts to returm relavent search results
using simple queries.
 
This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 NOTES

Uses result field $result->source which is helpful with this engine 
because the the URL is owner encoded. $result->source will display a 
plain base URL address and should be called after $result->description  


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 HOW DOES IT WORK?

C<native_setup_search> is called before we do anything.
It initializes our private variables (which all begin with underscores)
and sets up a URL to the first results page in C<{_next_url}>.

C<native_retrieve_some> is called (from C<WWW::Search::retrieve_some>)
whenever more hits are needed.  It calls the LWP library
to fetch the page specified by C<{_next_url}>.
It parses this page, appending any search hits it finds to 
C<{cache}>.  If it finds a ``next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we're done.

=head1 AUTHOR

C<WWW::Search::GoTo> is written by Jim Smyser
Author e-mail <jsmyser@bigfoot.com>

=head1 COPYRIGHT

Copyright (c) 1996-1999 University of Southern California.
All rights reserved.                                            

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=cut
#'

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.05';

$MAINTAINER = 'Jim Smyser <jsmyser@bigfoot.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('GoTo', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('GoTo', '$MAINTAINER', 'one_page', 'satur'.'nV', \$TEST_RANGE, 1,10);
&test('GoTo', '$MAINTAINER', 'multi', 'iro' . 'ver', \$TEST_GREATER_THAN, 20);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search {

      my($self, $native_query, $native_options_ref) = @_;
      $self->user_agent('user');
      $self->{_next_to_retrieve} = 0;
      if (!defined($self->{_options})) {
      $self->{_options} = {
           'search_url' => 'http://www.goto.com/d/search/p/befree/',
      };
      };
      my($options_ref) = $self->{_options};
      if (defined($native_options_ref)) {
      # Copy in new options.
      foreach (keys %$native_options_ref) {
          $options_ref->{$_} = $native_options_ref->{$_};
      };
      };
      # Process the options.
      my($options) = '';
      foreach (keys %$options_ref) {
      # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
      next if (generic_option($_));
      $options .= $_ . '=' . $options_ref->{$_} . '&';
      };
      $self->{_debug} = $options_ref->{'search_debug'};
      $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
      $self->{_debug} = 0 if (!defined($self->{_debug}));
      # Finally figure out the url.
      $self->{_base_url} = 
      $self->{_next_url} =
      $self->{_options}{'search_url'} .
      "?" . $options .
      "Keywords=" . $native_query;
      print $self->{_base_url} . "\n" if ($self->{_debug});
}


# private
sub native_retrieve_some {

      my ($self) = @_;
      # fast exit if already done
      return undef if (!defined($self->{_next_url}));
   
      # get some
      print STDERR "**FETCHING: " . $self->{_next_url} . "**\n" if ($self->{_debug});
      my($response) = $self->http_request('GET', $self->{_next_url});
      $self->{response} = $response;
      if (!$response->is_success) {
      return undef;
      };
   
      # parse the output
      my($HEADER, $HITS, $DESC, $SCORE, $POST_NEXT) = (1..10);
      my($hits_found) = 0;
      my($state) = ($HEADER);
      my($hit, $raw, $title, $url, $rating, $desc) = ();
      foreach ($self->split_lines($response->content())) {
      next if m@^$@; # short circuit for blank lines
   if ($state == $HEADER && m@<head>@i) { 
      # GoTo doesn't appear to display total pages found
      print STDERR "**FOUND HEADER**" if ($self->{_debug} >= 2);
      $state = $HITS;

 } elsif ($state == $HITS && 
      m|.*?<b><a href="(.*?)"\ target.*?>(.*)</a></b>.*?<font face=.*?>(.*)<br><em>(.*?)</em>|i) 
      { 
      print STDERR "**PARSING URL, TITLE, DESC.**\n" if ($self->{_debug} >= 2);
      my ($url, $title, $description, $sURL) = ($1,$2,$3,$4);
      my($hit) = new WWW::SearchResult;
      $url = 'http://goto.com' . $url;
      $hit->add_url($url);
      $hit->title($title);
      $hit->description($description);
      $hit->source($sURL);
      $hit->raw($_);
      $hits_found++;
      push(@{$self->{cache}}, $hit);
      $state = $HITS;

 } elsif ($state == $HITS && m@<.*?href="([^"]+)"><.*?>More Results<.*?>@i) { 
      my($relative_url) = $1;
      $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
      print STDERR "**GOING TO NEXT PAGE**\n" if ($self->{_debug} >= 2);
      $state = $POST_NEXT;
      } else {
      };
      };
   if ($state != $POST_NEXT) {
      # End here if no other 'next' page to get
      if (defined($hit)) {
      push(@{$self->{cache}}, $hit);
      };
      $self->{_next_url} = undef;
      };
      # zZZzZZZZZZZZzZZZZZZZZ
      $self->user_agent_delay if (defined($self->{_next_url}));
      return $hits_found;
      }
1;




