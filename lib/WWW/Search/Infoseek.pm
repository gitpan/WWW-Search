#!/usr/local/bin/perl -w

# Infoseek.pm
# Copyright (C) 1998 by Martin Thurn
# $Id: Infoseek.pm,v 1.11 1998/10/06 00:53:12 johnh Exp $

=head1 NAME

WWW::Search::Infoseek - class for searching Infoseek 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Infoseek');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a Infoseek specialization of WWW::Search.
It handles making and interpreting Infoseek searches
F<http://www.infoseek.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 SEE ALSO

  L<WWW::Search::Infoseek::Companies>
  L<WWW::Search::Infoseek::Web>
  L<WWW::Search::Infoseek::News>

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

See C<WWW::Search::Infoseek::Web> for test cases for the default usage.

=head1 AUTHOR

C<WWW::Search::Infoseek> is maintained by Martin Thurn
(MartinThurn@iname.com).

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 1.7, 1998-10-05

www.Infoseek.com changed their output format.
Thanks to Andreas Borchert (borchert@mathematik.uni-ulm.de) for patches.

=head2 1.6, 1998-09-18

Fixed BUG where (apparently) no titles were retrieved.

=head2 1.5

www.Infoseek.com changed their output format ever-so-slightly.

=head2 1.3

First publicly-released version.

=cut

#####################################################################

package WWW::Search::Infoseek;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search
  {
  my ($self, $native_query, $rhOptions) = @_;

  # WARNING: www.Infoseek.com returns 25 hits per page no matter what number
  # you send in the argument list!
  my $DEFAULT_HITS_PER_PAGE = 25;
  # $DEFAULT_HITS_PER_PAGE = 10;  # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  $self->{agent_e_mail} = 'MartinThurn@iname.com';

  # www.Infoseek.com doesn't like robots: response from server was 403
  # (Forbidden) Forbidden by robots.txt
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
    # These are the defaults:
    $self->{_options} = {
                         'search_url' => 'http://www.infoseek.com/Titles',
                         'qt' => $native_query,
                         'st' => $self->{'_next_to_retrieve'},
                         'nh' => $self->{'_hits_per_page'},
                         'rf' => '0',
                         'col' => 'WW',
                        };
    } # if

  # Copy in options passed in the argument list:
  if (defined($rhOptions)) 
    {
    foreach (keys %$rhOptions) 
      {
      $self->{'_options'}->{$_} = $rhOptions->{$_};
      } # foreach
    } # if

  # Copy in options which were set by a child object:
  my $rhChildOptions = $self->{'_child_options'};
  if (defined($self->{'_child_options'})) 
    {
    foreach (keys %{$self->{'_child_options'}}) 
      {
      $self->{'_options'}->{$_} = $self->{'_child_options'}->{$_};
      } # foreach
    } # if

  # Build the options part of the URL:
  my $options = '';
  foreach (keys %{$self->{'_options'}})
    {
    # printf STDERR "option: $_ is " . $self->{'_options'}->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $self->{'_options'}->{$_} . '&';
    }

  # Finally figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;

  # Set some private variables:
  $self->{_debug} = $self->{'_options'}->{'search_debug'};
  $self->{_debug} = 2 if ($self->{'_options'}->{'search_parse_debug'});
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
  my ($START, $HEADER, $HITS, $DESC,$PERCENT,$SIZE,$DATE, $NEXT,$COMP_NEXT, $TRAILER) = qw( ST HE HI DE PE SI DA NE CN TR );
  my $hits_found = 0;
  my $state = $START;
  my $hit;
  foreach (split(/\n/, $response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $START && 
	m=RESULT.*?\s+of\s+([\d,]+)\s+total results=i) # afb 10/98
      {
      # Actual line of input is:
      # <b>RESULTS 1 - 25</b>  of 192 total results
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      my $iCount = $1;
      $iCount =~ s/,//g;
      $self->approximate_result_count($iCount);
      $state = $HEADER;
      } # we're in START mode, and line has number of results
    elsif ($state eq $START && 
           m=<b>ARTICLES\s+\d+\s+-\s+\d+</b>\s+of\s+([0-9,]+)=)
      {
      # Actual line of input is:
      # <b>ARTICLES 1 - 25</b>  of 1,239 total articles <p>
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      my $iCount = $1;
      $iCount =~ tr/[^0-9]//;
      $self->approximate_result_count($1);
      $state = $HEADER;
      } # we're in START mode, and line has number of results

    elsif ($state eq $HEADER && 
           m@roup\sthese\sresults@)
      {
      # Actual line of input is:
      # <a href="/Titles?qt=star+wars+collector&col=WW&nh=25&rf=0">Ungroup these results</a>
      print STDERR "group/ungroup line\n" if 2 <= $self->{'_debug'};
      $state = $NEXT;
      } # we're in HEADER mode, and line talks about (un)grouping results
    elsif ($state eq $HEADER && 
           m@>Hide\ssummaries<@i)
      {
      # Actual line of input is:
      # <a href="/Titles?qt=star+wars+collector&col=WW&nh=25&rf=0">Ungroup these results</a>
      print STDERR "show/hide summaries line\n" if 2 <= $self->{'_debug'};
      $state = $COMP_NEXT;
      } # we're in HEADER mode, and line talks about (un)grouping results

    elsif (($state eq $NEXT || $state eq $COMP_NEXT) &&
           m@>Next(&nbsp;|\s+)\d+@i)
      {
      # Actual line of input is:
      #    &nbsp;&nbsp;|&nbsp;&nbsp;<a href="/Titles?qt=star+wars+collector&rf=11&st=50&nh=25&rf=11">Next&nbsp;25</a>
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      # Process the options.
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_options'}{'st'} = $self->{'_next_to_retrieve'};
      my($options) = '';
      foreach (keys %{$self->{_options}}) 
        {
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Finally, figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      $state = $HITS;
      }
    elsif ($state eq $NEXT && m=</font>=)
      {
      print STDERR " no next button\n" if 2 <= $self->{'_debug'};
      # There is no next button.
      $state = $HITS;
      }
    elsif ($state eq $COMP_NEXT && m=^<p>$=)
      {
      print STDERR " no next button (company mode)\n" if 2 <= $self->{'_debug'};
      # There is no next button.
      $state = $HITS;
      }
    elsif ($state eq $COMP_NEXT && m=^</td></tr></table>$=) # afb 10/98
      {
      print STDERR " no next button (web mode)\n" if 2 <= $self->{'_debug'};
      # There is no next button.
      $state = $HITS;
      }

    elsif ($state eq $HITS && 
           m=<b>Articles</b>\s+\d+\s+-\s+\d+\s+of\s+\d+=)
      {
      # Actual line of input is:
      # <b>Articles</b>  51  -  100  of  104
      print STDERR "article count line\n" if 2 <= $self->{'_debug'};
      $state = $TRAILER;
      }  
    elsif ($state eq $HITS && m/xxxxxx xxxxxx xxxxxx/)
      {
      print STDERR "xxxxxx line\n" if 2 <= $self->{'_debug'};
      $state = $TRAILER;
      }
    elsif ($state eq $HITS && m/>Hide\ssummaries</)
      {
      print STDERR "show/hide line\n" if 2 <= $self->{'_debug'};
      $state = $TRAILER;
      }
    elsif ($state eq $HITS && 
           m|<b><a\shref=\"([^\"]+)\">([^<]+)|i)
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <b><a href="http://www.wizardpress.com/68toychst.html">Wizard Press Columns and Departments:Toychest!</a></b><br>
      # Sometimes the </A> is on the next line.
      # Sometimes there is a /r right before the </A>
      my ($sURL,$sTitle) = ($1,$2);
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      # hits from Companies database are internal www.Infoseek.com links:
      $sURL = 'http://www.infoseek.com'. $sURL if $sURL =~ m@^/Content@;
      $hit->add_url($sURL);
      $self->{'_num_hits'}++;
      $hits_found++;
      $hit->title($sTitle);
      $state = $DESC;
      }

    elsif ($state eq $DESC &&
           m|<br>(.*)<br>$|)
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      # Sometimes description is empty
      $hit->description($1) if ref($hit);
      if ($hit->url =~ m/col=NX/)
        {
        # This a NEWS results page
        $state = $HITS;
        } 
      else
        {
        $state = $HITS;
        }
      } # line is description
    elsif ($state eq $DESC &&
           m|^(.+(\s\.\.?\.?)?)?\s&nbsp;\s&nbsp;\s*$|)
      {
      print STDERR "hit company description line\n" if 2 <= $self->{'_debug'};
      # Sometimes description is empty
      $hit->description($1) if ref($hit);
      $state = $HITS;
      } # line is description

    elsif ($state eq $HITS && m=(\d+)\%$=)
      {
      print STDERR "hit score line\n" if 2 <= $self->{'_debug'};
      $hit->score($1) if ref($hit);
      $state = $HITS;
      }

    elsif ($state eq $HITS && m=\(Size\s([0-9.KM]+)\)=)
      {
      print STDERR "hit size line\n" if 2 <= $self->{'_debug'};
      my $size = $1;
      $size =~ s/K/*1024/;
      $size =~ s/M/*1024*1024/;
      $hit->size(eval $size) if ref($hit);
      $state = $HITS;
      }

    elsif ($state eq $HITS && m=Date:(&nbsp;)?\s*(\d+\s+[A-Z][a-z]+\s+\d+)=)
      {
      print STDERR "hit change_date line\n" if 2 <= $self->{'_debug'};
      # Actual line of input is:
      # Document&nbsp;date: 22 Oct 1996 </font><br>
      $hit->change_date($2) if ref($hit);
      $state = $HITS;
      }
    elsif ($state eq $HITS && m=^(<b>)?([a-zA-Z]+\s+\d+\s+[a-zA-Z]+\s+[\d:]+)(</b>)?=)
      {
      print STDERR "hit news date line\n" if 2 <= $self->{'_debug'};
      # Actual lines of input include:
      # Document&nbsp;date: 22 Oct 1996 </font><br>
      # Wed 19 Aug 13:38
      $hit->change_date($2) if ref($hit);
      $state = $HITS;
      }

    else
      {
      print STDERR "didn't match\n" if 2 <= $self->{'_debug'};
      }
    } # foreach line of query results HTML page

  if (defined($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    }
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__

Martin''s page download results, 1998-04:

values of URL fields:
st = starting result # (round down to multiple of 5?)
nh = number of hits per page (round down to multiple of 5)
rf = 0 means do not group results by site
col = HV for search on companies
col = WW for search on web
col = NX for search on news

default Companies search:

http://www.infoseek.com/Titles?qt=cable+tv&col=HV%2Ckt_N%2Cak_corpdir&sv=IS&lk=noframes&nh=10

simple Companies search:

http://www.infoseek.com/Titles?qt=cable+tv&col=HV&nh=10

