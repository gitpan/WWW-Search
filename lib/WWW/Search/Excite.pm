#!/usr/local/bin/perl -w

# Excite.pm
# Copyright (C) 1998 by USC/ISI
# by Martin Thurn
# $Id: Excite.pm,v 1.9 1998/03/31 22:29:36 johnh Exp $

package WWW::Search::Excite;

=head1 NAME

WWW::Search::Excite - class for searching Excite 

=head1 DESCRIPTION

This class is a Excite specialization of WWW::Search.
It handles making and interpreting Excite searches
F<http://www.excite.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 HOW DOES IT WORK?

C<native_setup_search> is called (from C<WWW::Search::setup_search>)
before we do anything.  It initializes our private variables (which
all begin with underscore) and sets up a URL to the first results
page in C<{_next_url}>.

C<native_retrieve_some> is called (from C<WWW::Search::retrieve_some>)
whenever more hits are needed.  It calls C<WWW::Search::http_request>
to fetch the page specified by C<{_next_url}>.
It then parses this page, appending any search hits it finds to 
C<{cache}>.  If it finds a ``next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we''re done.


=head1 BUGS

Please tell the author if you find any!


=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

  Test cases:
 '+mrfglbqnx +NoSuchWord'          ---   no hits
 'disestablishmentarianism'        ---   13 hits on one page
 '+Jabba +bounty +hunter +Greedo'  ---  129 hits on two pages


=head1 AUTHOR

As of 1998-03-23, C<WWW::Search::Excite> is maintained by Martin Thurn
(mthurn@irnet.rest.tasc.com).

C<WWW::Search::Excite> was originally written by Martin Thurn
based on C<WWW::Search::HotBot>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=head1 VERSION HISTORY

=head2 1.2

First publicly-released version.


=cut

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;

  my $DEFAULT_HITS_PER_PAGE = 100;
  # $DEFAULT_HITS_PER_PAGE = 30;  # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  # Add one to the number of hits needed, because Search.pm does ">"
  # instead of ">=" on line 672!
  my $iMaximum = 1 + $self->maximum_to_retrieve;
  # Divide the problem into N pages of K hits per page.
  my $iNumPages = 1 + int($iMaximum / $self->{'_hits_per_page'});
  if (1 < $iNumPages)
    {
    $self->{'_hits_per_page'} = 1 + int($iMaximum / $iNumPages);
    }
  else
    {
    $self->{'_hits_per_page'} = $iMaximum;
    }

  $self->{agent_e_mail} = 'mthurn@irnet.rest.tasc.com';
  $self->user_agent(0);

  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;

  # Remove '*' at end of query terms within the user's query.  If the
  # query string is not escaped (even though it's supposed to be),
  # change '* ' to ' ' at end of words and at the end of the string.
  # If the query string is escaped, change '%2A+' to '+' at end of
  # words and delete '%2A' at the end of the string.
  $native_query =~ s/(\w)\052\s/$1\040/g;
  $native_query =~ s/(\w)\052$/$1\040/g;
  $native_query =~ s/(\w)\0452A\053/$1\053/g;
  $native_query =~ s/(\w)\0452A$/$1/g;
  if (!defined($self->{_options})) 
    {
    $self->{_options} = {
                         'search_url' => 'http://search.excite.com/search.gw',
                         'perPage' => $self->{'_hits_per_page'},
                         'showSummary' => 'true',
                         'start' => $self->{'_next_to_retrieve'},
                         'search' => $native_query,
                        };
    } # if
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
  my ($HEADER, $HITS, $DESC, $TRAILER) = qw(HE HH DE TR);
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
  foreach (split(/\n/, $response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $HEADER && 
        m=^\s\s\smatches.+?\[(\d+)\shits\.\sAbout\sYour\sResults\]=)
      {
      # Actual line of input is:
      #    matches. <FONT SIZE=-1><A HREF=/search.gw?s=&numDocs=66469&mode=about&sorig=a><I>[66469 hits. About Your Results]</I></A></FONT>
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HEADER && 
           m=^\s+&nbsp;\d+-(\d+)</FONT>=)
      {
      # Actual line of input is:
      #       &nbsp;1-4</FONT>
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      unless (defined($self->approximate_result_count) and 0 < $self->approximate_result_count)
        {
        $self->approximate_result_count($1);
        } # if
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HITS && 
           m|<B>\d+\%\s*</B>.+?<A\s+HREF=\"([^\"]+)\">([^<]+)|i)
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      #          <FONT COLOR=navy><B>66% </B></FONT>          <B><A HREF="http://www.wwwishbone.com/WWWishbone/MyShow/TheCast/cast.html">WORLDWIDE WISHBONE(TM)</A></B>&nbsp;
      # Sometimes the </A> is on the next line.
      # Sometimes there is a /r right before the </A>
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $self->{'_num_hits'}++;
      $hits_found++;
      $hit->title($2);
      $state = $DESC;
      }
    elsif ($state eq $DESC &&
           m=Summary:\s*</I></B>(.+?)<BR><B><I>More=)
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      $hit->description($1);
      $state = $HITS;
      } # line is description

    elsif ($state eq $HITS &&
           m/<input\s[^>]*value=\"Next\sResults\"/i)
      {
      # Actual lines of input include:
      #                 <INPUT TYPE=submit NAME=next VALUE="Next Results">
      #                 <input value="Next Results" type="submit" name="next">
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      # Process the options.
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_options'}{'start'} = $self->{'_next_to_retrieve'};
      my($options) = '';
      foreach (keys %{$self->{_options}}) 
        {
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Finally, figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
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

__END__

Martin''s page download notes, 1998-03:

fields on advanced search page:
c	(select) search where: 'web','web.review','timely','web.de','web.fr','web.uk','web.se'
FT_1	(select) 'w' the word(s) or 'p' the phrase for MAY contain
FL_1	(hidden) '3'
FI_1	(text) the search terms (MAY contain)
FT_2	(select) 'w' the word(s) or 'p' the phrase for MUST contain
FL_2	(hidden) '4'
FI_2	(text) search terms (MUST NOT contain)
FT_3	(select) 'w' the word(s) or 'p' the phrase for MUST NOT contain
FL_3	(hidden) '2'
FI_3	(text) search terms (MUST NOT contain)
mode	(hidden) 'advanced'
numFields (hidden) '3'
lk	(hidden) 'default'
sort	(radio) 'relevance' or 'site'
showSummary (select) 'true' titles & summaries or 'false' titles only
perPage (select) '10','20','30','40','50'

simplest pages, normal search:

http://search.excite.com/search.gw?search=Martin+Thurn&start=0&showSummary=true&perPage=50
http://search.excite.com/search.gw?search=Martin+Thurn&start=150&showSummary=true&perPage=50

simplest first page, advanced search:

http://search.excite.com/search.gw?c=web&FT_1=w&FI_1=Christie+Abbott&mode=advanced&numFields=3&sort=relevance&showSummary=true&perPage=50

