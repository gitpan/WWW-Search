#!/usr/local/bin/perl -w

# Magellan.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: Magellan.pm,v 1.5 1998/08/27 17:29:03 johnh Exp $

package WWW::Search::Magellan;

=head1 NAME

WWW::Search::Magellan - class for searching Magellan 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Magellan');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    print $oResult->url, "\n";

=head1 DESCRIPTION

This class is a Magellan specialization of WWW::Search.
It handles making and interpreting Magellan searches
F<http://www.mckinley.com>.

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
 '+mrfglbqnx +NoSuchWord'    ---   no hits
 'disestablishmentarianism'  ---   1 hits on one page
 '+Martin +Thurn'            ---  11 hits on two pages


=head1 AUTHOR

As of 1998-03-17, C<WWW::Search::Magellan> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::Magellan> was originally written by Martin Thurn
based on C<WWW::Search::WebCrawler>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=head1 VERSION HISTORY

=head2 1.6

Now parses score (percentage) from Magellan's output.

=head2 1.2

First publicly-released version.


=cut

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;

  # Magellan doesn't seem to let you change the number of hits per page.
  my $DEFAULT_HITS_PER_PAGE = 10;
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  # Add one to the number of hits needed, because Search.pm does ">"
  # instead of ">=" on line 672!
  my $iMaximum = 1 + $self->maximum_to_retrieve;

  $self->{agent_e_mail} = 'MartinThurn@iname.com';
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
                         'search_url' => 'http://www.mckinley.com/search.gw',
                         'search' => $native_query,
                         'start' => $self->{'_next_to_retrieve'},
                         'look' => 'magellan',
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
  my ($HEADER1,$HEADER2, $HITS,$PERCENT,$H3, $DESC, $TRAILER) = qw(E1 E2 HH PE H3 DE TR);
  my $hits_found = 0;
  my $state = $HEADER1;
  my $hit;
  foreach ($self->split_lines($response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $HEADER1 && 
        m{^<B>(\d+)</B>\sresults\sreturned})
      {
      # Actual line of input is:
      # <B>377</B> results returned, ranked by relevance.
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HEADER2;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HEADER2 &&
          m{^<!--search\sresults-->})
      {
      print STDERR "header end line\n" if 2 <= $self->{'_debug'};
      $state = $HITS;
      }
    elsif ($state eq $HITS && 
           m{<B><A\sHREF=\"([^\"]+)\">([^<]+)})
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      #   <B><A HREF="http://www.tez.net/~arthurd/starwars.html">The Star Wars List of Links</A></B>&nbsp;&nbsp;&nbsp;
      # Sometimes there is an \r and/or \n before the </A>
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hit->title($2);
      $self->{'_num_hits'}++;
      $hits_found++;
      $state = $PERCENT;
      }
    elsif ($state eq $PERCENT &&
           m{>(\d+)\%<})
      {
      print STDERR "hit percent line\n" if 2 <= $self->{'_debug'};
      # Actual line of input is:
      #   <B>45%</B>&nbsp;&nbsp;&nbsp;
      $hit->score($1);
      $state = $H3;
      next;
      }
    elsif ($state eq $H3)
      {
      print STDERR "hit ignore line 3\n" if 2 <= $self->{'_debug'};
      $state = $DESC;
      next;
      }
    elsif ($state eq $DESC)
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      $hit->description($_);
      $state = $HITS;
      } # line is description

    elsif ($state eq $HITS && m{<input\s.*?\sVALUE=\"Next\sResults\"}i)
      {
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # Actual lines of input are:
      #              <input value="Next Results" type="submit" name="next">
      #              <INPUT TYPE=submit NAME=next VALUE="Next Results">
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
      last;
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

Martin''s page download results, 1998-03:

simplest arbitrary page:

http://www.mckinley.com/search.gw?search=%2Bstar+%2Bwars+%2Bbible&c=web&look=magellan&x=23&y=17
http://www.mckinley.com/search.gw?search=%2Bstar+%2Bwars+%2Bbible&look=magellan&start=8&c=web

Here''s what I''m generating:

