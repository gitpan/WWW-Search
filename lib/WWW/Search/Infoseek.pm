# Infoseek.pm
# Copyright (C) 1998 by Martin Thurn
# $Id: Infoseek.pm,v 1.16 1999/06/30 15:07:12 mthurn Exp $

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

If it is not listed here, then it was not a meaningful nor released revision.

=head2 1.16, 1999-06-30

Now strips HTML tags from titles and descriptions.

=head2 1.14, 1999-06-29

Companies and News searches now work!

=head2 1.13, 1999-06-28

www.infoseek.com changed their output format ever so slightly.
Companies and News searches return URLs, but titles and descriptions are unreliable.

=head2 1.12, 1999-05-21

www.infoseek.com changed their output format.

=head2 1.11, 1999-04-27

Fixed BUG in parsing of News search results.
Added version method.

=head2 1.08, 1999-02-09

Fixed BUG in parsing of Companies search results.
Thanks to Jim Smyser (jsmyser@bigfoot.com) for pointing it out.

=head2 1.7, 1998-10-05

www.infoseek.com changed their output format.
Thanks to Andreas Borchert (borchert@mathematik.uni-ulm.de) for patches.

=head2 1.6, 1998-09-18

Fixed BUG where (apparently) no titles were retrieved.

=head2 1.5

www.infoseek.com changed their output format ever-so-slightly.

=head2 1.3

First publicly-released version.

=cut

#####################################################################

package WWW::Search::Infoseek;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.16';

use Carp ();
use WWW::Search(qw( generic_option strip_tags ));
require WWW::SearchResult;
use URI;

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
  
  # A macro for HTML whitespace:
  my $SPACE = '(&nbsp;|\s)+';

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
  my ($START, $HEADER, $HITS, $DESC,$PERCENT,$SIZE,$DATE, $NEXT,$COMP_NEXT, $TRAILER,
     $WEB_HITS, $WEB_NEXT) = qw( ST HE HI DE PE SI DA NE CN TR WH WN );
  my $hits_found = 0;
  my $state = $START;
  my $hit;
  my $sContent = $response->content();
  $sContent =~ s/<p>/\n/g;
  foreach ($self->split_lines($sContent))
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $START && 
	m=web\ssearch\sresults=i &&
	m=of\s+<b>([\d,]+)</b>\s+results=i)
      {
      # Actual line of input is:
      # <tr><td valign="middle" align="left" nowrap colspan="3"><font face="Helvetica,Arial" size="3" color="#FFFFFF"><a name="search">&nbsp;<b>Web search results</b>&nbsp;&nbsp;&nbsp;&nbsp;<font face="Helvetica,Arial" size="2">1 - 10 of <b>99</b> results most relevant to <b>martin thurn</b> </font>&nbsp;</a></font></td>
      print STDERR "web header line\n" if 2 <= $self->{'_debug'};
      my $iCount = $1;
      $iCount =~ s/,//g;
      $self->approximate_result_count($iCount);
      $state = $NEXT;
      next;
      } # we're in START mode, and line has number of WEB results

    if ($state eq $START && 
           m=\>\d+\s+-\s+\d+\s+of\s+<b>([0-9,]+)=)
      {
      # Actual line of input is:
      # <b>ARTICLES 1 - 25</b>  of 1,239 total articles <p>
      # <tr><td valign="middle" align="left" nowrap colspan="3"><font face="Helvetica,Arial" size="3" color="#FFFFFF"><a name="search">&nbsp;<b>Web search results</b>&nbsp;&nbsp;&nbsp;&nbsp;<font face="Helvetica,Arial" size="2">1 - 25 of <b>97</b> results most relevant to <b>Martin Thurn</b> </font>&nbsp;</a></font></td>
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      my $iCount = $1;
      $iCount =~ tr/[^0-9]//;
      $self->approximate_result_count($1);
      $state = $HEADER;
      next;
      } # we're in START mode, and line has number of results

#      if ($state eq $HEADER && 
#             m@roup\sthese\sresults@)
#        {
#        # Actual line of input is:
#        # <a href="/Titles?qt=star+wars+collector&col=WW&nh=25&rf=0">Ungroup these results</a>
#        print STDERR "group/ungroup line\n" if 2 <= $self->{'_debug'};
#        $state = $NEXT;
#        next;
#        } # we're in HEADER mode, and line talks about (un)grouping results
#      if ($state eq $HEADER && 
#             m@>Hide\ssummaries<@i)
#        {
#        # Actual line of input is:
#        # <b><a href="http://infoseek.go.com/Titles?rf=0&qt=Lycos&col=HV&nh=20&st=0&&sf=1&ud4=1"><font size="-1">Hide summaries</font></a></b>
#        print STDERR "show/hide summaries line\n" if 2 <= $self->{'_debug'};
#        $state = $COMP_NEXT;
#        next;
#        } # we're in HEADER mode, and line talks about hide summaries

    if ((($state eq $NEXT) || 
         ($state eq $WEB_NEXT)) &&
        s@<a href=\"(.*?)\">Next$SPACE\d+@WWWSEARCHDELETED@i)
      {
      # Actual line of input is:
      # <font face="Helvetica,Arial" size="2"><b><a href="http://infoseek.go.com/Titles?qt=martin+thurn&col=WW&sv=IS&lk=noframes&svx=home_searchbox&st=10">Next 10 ></a></b> &nbsp;|&nbsp; ...
      print STDERR " found 'next' link\n" if 2 <= $self->{'_debug'};
      # There is a "next" link on this page, therefore there are
      # indeed more results for us to go after next time.
      $self->{_next_url} = $1;
      $state = $WEB_HITS;
      # Stay on this line of input!
      }
    elsif ($state eq $NEXT &&
           (s@^.*?<a href=\"(.*?)\">Group\sresults@WWWSEARCHDELETED@i ||
            m!\">Hide\ssummaries!i))
      {
      print STDERR " no 'next' link\n" if 2 <= $self->{'_debug'};
      $self->{_next_url} = undef;
      $state = $WEB_HITS;
      # Stay on this line of input!
      }

    if ($state eq $WEB_HITS && s!<b><a href=\"(.*?)\">(.*?)</a>!!i)
      {
      print STDERR " hit URL line\n" if 2 <= $self->{'_debug'};
      my ($sURL,$sTitle) = ($1,$2);
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        $self->{'_num_hits'}++;
        } # if
      $hits_found++;
      $hit = new WWW::SearchResult;
      my $sURLabs = URI->new_abs($sURL, $self->{_options}{search_url});
      $hit->add_url($sURLabs);
      $hit->title(strip_tags($sTitle));
      $state = $DESC;
      $hit->score($1) if (m/(\d+)\%$SPACE/i);
      $hit->change_date($1) if (m/Date:\s(.*?)</i);
      $hit->description(strip_tags($1)) if (s!<br>(.*?)<br>!!);
      if (m/Size\s(\S+?),/i)
        {
        my $size = $1;
        $size =~ s/K/*1024/;
        $size =~ s/M/*1024*1024/;
        $hit->size(int eval $size);
        $state = $WEB_HITS;
        } # if
      }
    elsif ($state eq $DESC && s!^<br>(.*?)<br>!!)
      {
      print STDERR " description line\n" if 2 <= $self->{'_debug'};
      $hit->description(strip_tags($1));
      $hit->change_date($1) if (m/^<b>(.*?)\s&nbsp;/i);
      $state = $WEB_HITS;
      } # if

    # if (($state eq $NEXT || $state eq $COMP_NEXT) && m=^\s*</FONT>\s*$=i)
    #   {
    #   print STDERR " no next button\n" if 2 <= $self->{'_debug'};
    #   # There is no next button.
    #   $state = $HITS;
    #   }
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
      # Ignore Infoseek-internal redirects (advertisements, etc.)
      unless ($sURL =~ m!^/redirect!i)
        {
        # hits from Companies database are internal www.Infoseek.com links:
        $sURL = 'http://www.infoseek.com'. $sURL if $sURL =~ m@^/Content@;
        if (defined($hit))
          {
          push(@{$self->{cache}}, $hit);
          }
        $hit = new WWW::SearchResult;
        $hit->add_url($sURL);
        $self->{'_num_hits'}++;
        $hits_found++;
        $hit->title(strip_tags($sTitle));
        $state = $DESC;
        } # unless
      } # old URL line

    elsif ($state eq $DESC &&
           m|<br>(.*?)<br>$|)
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      # Sometimes description is empty
      $hit->description(strip_tags($1)) if ref($hit);
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
      $hit->description(strip_tags($1)) if ref($hit);
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

    elsif ($state eq $HITS && m=Date:$SPACE(\d+\s+[A-Z][a-z]+\s+\d+)=)
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

