#!/usr/local/bin/perl -w

#
# Snap.pm
# by Jim Smyser
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Snap.pm,v 1.2 1998/12/09 20:00:04 johnh Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::Snap;

=head1 NAME

WWW::Search::Snap - class for searching Snap.com! 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Snap');

=head1 DESCRIPTION

Public release version.

Class specialization of WWW::Search for searching Snap.com.
Defaults to searching ALL terms. See line 128 to set to boolean.
Snap.com can return up to 1000 hits.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 OPTIONS

The default is for ALL words in queries and with additional 
use of (+), (-) and Double-Quotes (" ") to refine a search.
Example: "WWW::Search" returns pages with WWW::Search. Case important:
"www::search" returns nothing. 

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>,
or the specialized AltaVista searches described in options.

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

C<WWW::Search::Snap> is written and maintained
by Jim Smyser - <jsmyser@bigfoot.com>.

=head1 TESTING

Supports the WWW::Search test routines. 

$file = 'test/Snap/zero_result';
$query = 'Bogus' . 'NoSuchWord';
test($mode, $TEST_EXACTLY);

$file = 'test/Snap/one_page_result';
$query = 'Visual Basic' . AND . 'FindWindow'. AND . 'Close';
test($mode, $TEST_RANGE, 2, 99);

$file = 'test/Snap/multi_page_result';
$query = 'arizona' . 'mountains' . 'ski' . 'boat' . 'fish' . 'cabin';
test($mode, $TEST_GREATER_THAN, 100);


=head1 COPYRIGHT

Copyright (c) 1996-1998 University of Southern California.
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

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.4';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;
  $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
  $self->user_agent(1);
  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;
  if (!defined($self->{_options})) {
    $self->{_options} = {
        'search_url' => 'http://www.snap.com/search/power/results/1,180,home-0,00.html',
          'KM' => 'a', # b = boolean  a = AND
          'KW' => $native_query,
          'AM0' => 'm',
          'AT0' => 'w',
          'AK0' => '',
          'AN' => '1',
          'NR' => '100',
          'FR' => 'f',
          'PL' => 'a',
          'DR' => '0',
          'FM' => '1',
          'FD' => '1',
          'XT' => '',
          'DM' => '',
          'LN' => '',
           };
                } 
  my $options_ref = $self->{_options};
  if (defined($native_options_ref)) 
    {
    # Copy in new options.
    foreach (keys %$native_options_ref) 
      {
      $options_ref->{$_} = $native_options_ref->{$_};
      } # foreach
    } # if

  # Process the options.
  my $options = '';
  foreach (keys %$options_ref) 
    {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }

  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;

  # Set some private variables:
  $self->{_debug} = $options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
  $self->{_debug} = 0 if (!defined($self->{_debug}));
  } # native_setup_search

# private
sub native_retrieve_some
  {
  my ($self) = @_;
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  # Get some results, adhering to the WWW::Search mechanism:
  print STDERR " *   sending request (",$self->{_next_url},")\n" if $self->{'_debug'};
  my($response) = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    };
  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($HEADER, $HITS, $SCORE, $DESC, $TRAILER) = qw(HE HI SC DE TR);
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
  foreach ($self->split_lines($response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $HEADER && m{Results:\s(\d+)}i) {
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
    } elsif ($state eq $HITS && m{<b><a href="(.*?)">(.*?)</a></b><br>}) {
      print STDERR "hit found\n" if 2 <= $self->{'_debug'};
      push(@{$self->{cache}}, $hit) if defined($hit);
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hit->title($2);
      $self->{'_num_hits'}++;
      $hits_found++;
      $state = $DESC;
    } elsif ($state eq $DESC && m{([^"]+)(.*)<br>}i) {
      print STDERR "hit percentage line\n" if 2 <= $self->{'_debug'};
      $hit->description($1);
      $state = $HITS;
    } elsif ($state eq $HITS && m{</font></ul>}i) {
      # End of hits  
      print STDERR "PARSE(HITS->TRAILER): $_\n\n" if ($self->{_debug} >= 2);
      $state = $TRAILER;
    } elsif ($state eq $TRAILER && m{<A HREF="([^"]+)">Next</A>}i) {
      my($options) = $1;
      foreach (keys %{$self->{_options}}) 
        {
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Finally, figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      print STDERR " found next button, next url is $self->{_next_url}\n" if 2 <= $self->{'_debug'};
      $state = $TRAILER;
      }
    else
      {
      print STDERR "didn't match\n" if 2 <= $self->{'_debug'};
      }
    } # foreach line of query results HTML page

  if ($state ne $TRAILER)
    {
    # End, no other pages (missed some tag somewhere along the line?)
    $self->{_next_url} = undef;
    }
  if (defined($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    }
  return $hits_found;
  } # native_retrieve_some

1;


