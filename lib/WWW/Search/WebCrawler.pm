#!/usr/local/bin/perl -w

# WebCrawler.pm
# Copyright (C) 1998 by Martin Thurn
# $Id: WebCrawler.pm,v 1.1 1998/03/31 22:29:38 johnh Exp $

package WWW::Search::WebCrawler;

=head1 NAME

WWW::Search::WebCrawler - class for searching WebCrawler 

=head1 DESCRIPTION

This class is a WebCrawler specialization of WWW::Search.
It handles making and interpreting WebCrawler searches
F<http://www.WebCrawler.com>.

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


=head1 AUTHOR

As of 1998-03-16, C<WWW::Search::WebCrawler> is maintained by Martin Thurn
(mthurn@irnet.rest.tasc.com).

C<WWW::Search::WebCrawler> was originally written by Martin Thurn
based on C<WWW::Search::HotBot>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=head1 VERSION HISTORY

=head2 1.3

First publicly-released version.


=cut

#  Test cases:
# '+mrfglbqnx +NoSuchWord'    ---   no hits
# 'disestablishmentarianism'  ---   13 hits on one page
# 'Greedo'                    ---  129 hits on two pages

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

  # As of 1998-03-16, WebCrawler apparently doesn't like WWW::Search!  Response was
  # 403 (Forbidden) Forbidden by robots.txt
  $self->user_agent(1);

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
                         'search_url' => 'http://webcrawler.com/cgi-bin/WebQuery',
                         'search' => $native_query,
                         'start' => $self->{'_next_to_retrieve'},
                         'showSummary' => 'true',
                         'perPage' => $self->{'_hits_per_page'},
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
  # Delete the last '&' (WebCrawler chokes if it is there!) :
  chop $options;

  # Finally figure out the url.
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
        m@^Results\s+\d+-\d+\s+of\s+(\d+)\s+for\s+<B>(.*)</B>@i) 
      {
      # Actual line of input is:
      # Results 26-50 of 46642 for <B>star wars collecting</B>
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HEADER && 
           m@^Top\s+\d+\s+of\s+(\d+)\s+for\s+<B>(.*)</B>@i) 
      {
      # Actual line of input is:
      # Top 6 of 6 for <B>LSAM</B>
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HITS && 
           m|<B>\d+\%\s*</B>.+?<A\s+HREF=\"([^\"]+)\">([^<]+)|i)
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <BR><FONT FACE="Times" COLOR="#006699"><B>79% </B></FONT>&nbsp;&nbsp;<A HREF="http://www.geocities.com/Area51/Chamber/4729/">BACK TO THE FUTURE COLLECTABLES</A>
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
           m|^<DD>(.+)$|)
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      $hit->description($1);
      $state = $HITS;
      } # line is description

    elsif ($state eq $HITS && m/^<INPUT\s(TYPE=\"submit\"\s)?VALUE=\"Get\sthe\s(next|last)\s/i)
      {
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
      # Delete the last '&' (WebCrawler chokes if it is there!) :
      chop $options;
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

Martin''s page download results, 1998-02:

simplest arbitrary page:

http://webcrawler.com/cgi-bin/WebQuery?search=star+wars+collecting;showSummary=true;perPage=25;start=0

Here''s what I''m generating:

http://webcrawler.com/cgi-bin/WebQuery?search=LSAM;perPage=24;start=0;showSummary=true;
http://webcrawler.com/cgi-bin/WebQuery?search=LSAM;perPage=30;start=0;showSummary=true;
