#!/usr/local/bin/perl -w

#
# HotBot.pm
# by Wm. L. Scheding and Martin Thurn
# $Id: HotBot.pm,v 1.5 1998/02/19 18:28:36 johnh Exp $
#

package WWW::Search::HotBot;

=head1 NAME

WWW::Search::HotBot - class for searching HotBot 

=head1 DESCRIPTION

This class is a HotBot specialization of WWW::Search.
It handles making and interpreting HotBot searches
F<http://www.hotbot.com>.

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

This module should support options.


=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 


=head1 AUTHOR

As of 1998-02-02, C<WWW::Search::HotBot> is maintained by Martin Thurn
(mthurn@irnet.rest.tasc.com).

C<WWW::Search::HotBot> was originally written by Wm. L. Scheding,
based on C<WWW::Search::AltaVista>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


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
  # print STDERR " * this is Martin's new Hotbot.pm!\n" if $self->{'_debug'};
  # Why waste time sending so many queries?  Do a whole lot all at once!
  my $DEFAULT_HITS_PER_PAGE = 100;
  $DEFAULT_HITS_PER_PAGE = 10;   # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;
  # Add one to the number of hits needed, because Search.pm does ">"
  # instead of ">=" on line 672!
  $self->{'maximum_to_retrieve'}++;
  # Divide the problem into N pages of K hits per page.
  my $iNumPages = int(0.999 + 
                      $self->{'maximum_to_retrieve'} / $self->{'_hits_per_page'});
  if (1 < $iNumPages)
    {
    $self->{'_hits_per_page'} = int($self->{'maximum_to_retrieve'} / $iNumPages);
    }
  else
    {
    $self->{'_hits_per_page'} = $self->{'maximum_to_retrieve'};
    }
  $self->timeout(120);  # HotBot is notoriously slow
  # $self->{agent_name} = 'Mozilla/4.04 [en] (X11; I; SunOS 5.6 sun4m)';
  # $self->{agent_name} = 'W3CCommandLine/unspecified';
  $self->{agent_e_mail} = 'mthurn@irnet.rest.tasc.com';
  # $self->{agent_e_mail} = '.';

  # As of 1998-02-05, HotBot apparently doesn't like WWW::Search!  Response was
  # RC: 403 (Forbidden)
  # Message: Forbidden by robots.txt
  $self->user_agent(1);

  $self->{_next_to_retrieve} = 0;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options})) 
    {
    $self->{_options} = {
                         'search_url' => 'http://www.search.hotbot.com/hResult.html',
                         'DE' => 2,
                         'SM' => 'SC',
                         'DC' => $self->{_hits_per_page},
                         'MT' => $native_query,
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
  my($options) = '';
  foreach (keys %$options_ref) 
    {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  # Finally figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;

  $self->{_debug} = $options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
  $self->{_debug} = 0 if (!defined($self->{_debug}));
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  # print STDERR " *   HotBot::native_retrieve_some()\n" if $self->{'_debug'};
  
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  
  # print STDERR " * search_from_file is set!\n" if $self->{search_from_file};
  # print STDERR " * search_to_file is set!\n" if $self->{search_to_file};
  # Get some results
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
  my ($TITLE, $HEADER, 
      $HITS, $HIT1, $HIT2, $HIT3, $HIT4, $HIT5,
      $NEXT, $TRAILER) = qw(TI HE HH H1 H2 H3 H4 H5 NX TR);
  my ($hits_found) = 0;
  my ($state) = ($TITLE);
  my ($hit) = ();
  foreach (split(/\n/, $response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " * $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $TITLE && 
        m@<TITLE>HotBot results:\s+(.+)\s\(\d+\+\)</TITLE>@i) 
      {
      # Actual line of input is:
      # <HEAD><TITLE>HotBot results: Christie Abbott (1+)</TITLE>
      print STDERR "title line\n" if 2 <= $self->{'_debug'};
      $state = $HEADER;
      } # We're in TITLE mode, and line has title
    elsif ($state eq $HEADER && 
           m@<B>Returned:\s*</B>\s*(\d+)\s+matches\.@i) 
      {
      # Actual line of input is:
      # <B>Returned:</B> 3379 matches.
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $NEXT;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HITS && 
           m|^(<TR>)?<TD[^>]*><B>(\d+)\.\s</B>|)
      {
      print STDERR "hit number line\n" if 2 <= $self->{'_debug'};
      # Actual lines of input include:
      # <TR><TD  width="20" align="left" valign="top"><B>12. </B>
      # <TD  width="20" align="left" valign="top"><B>13. </B>
      my $iHit = $2;
      $state = $HIT1;
      }
    elsif ($state eq $HIT1)
      {
      print STDERR " skip (HIT1)\n" if 2 <= $self->{'_debug'};
      # Just skip this line:
      $state = $HIT2;
      }
    elsif ($state eq $HIT2 &&
           m|<A\s+HREF=\"([^\043]+)\">(.*)</A>|i) 
      {
      # \043 is double-quote character "
      # Actual line of input is:
      # <TD ><A HREF="http://bcrazy.simplenet.com/STARLETS/ABC/CA_WI/CA_WI.HTM" TARGET="preview"><IMG SRC="/images/btn.openpage.white.gif"  BORDER=0 WIDTH=17 HEIGHT=16 ALT="[VIEW]"></A>&nbsp;&nbsp;<A HREF="http://bcrazy.simplenet.com/STARLETS/ABC/CA_WI/CA_WI.HTM">Christie Abbott Wishbone II</A>
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # At this point, we could do something about "alternate" URLs
      # (like ignore them), but then our total hit count will get all
      # out of whack...?
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $self->{'_num_hits'}++;
      $hits_found++;
      $hit->title($2);
      if (! m/<FONT\sSIZE=-1>\(alternate\)/)
        {
        $state = $HIT3;
        }
      else
        {
        # Some problem, get ready for next hit
        $state = $HITS;
        } # This line is the hit url
      } # $state eq HIT2
    elsif ($state eq $HIT3)
      {
      print STDERR " skip (HIT3)\n" if 2 <= $self->{'_debug'};
      # Just skip this line:
      $state = $HIT4;
      } # $state eq HIT3
    elsif ($state eq $HIT4)
      {
      print STDERR " skip (HIT4)\n" if 2 <= $self->{'_debug'};
      # Just skip this line:
      $state = $HIT5;
      } # $state eq HIT4
    elsif ($state eq $HIT5 && m|^<TD\s*>(.*)<BR>$|)
      {
      print STDERR " hit description\n" if 2 <= $self->{'_debug'};
      # Actual input line is:
      # <TD >Text Files Maintained by Gus Lopez (lopez@cs.washington.edu) Ever wonder which weapon goes with which figure? Well, that's the kind of information you can find right here. Any beginning collector should glance at some of these files since they...<BR>
      $hit->description($1);
      $state = $HITS;
      } # line is description
    elsif ($state eq $NEXT && m|</FORM>|)
      {
      print STDERR " missed next button\n" if 2 <= $self->{'_debug'};
      # There was no "next" button on this page; no more pages to get!
      $self->{'_next_url'} = undef;
      $state = $HITS;
      }
    elsif ($state eq $NEXT && m|act.next|)
      {
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      # Process the options.
      $self->{_options}{'base'} = $self->{'_next_to_retrieve'};
      $self->{_options}{'act.next.x'} = 1;
      my($options) = '';
      foreach (keys %{$self->{_options}}) 
        {
        # printf STDERR "option: $_ is " . $self->{_options}{$_} . "\n";
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Finally figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $state = $HITS;
      }
    else
      {
      print STDERR "didn't match\n" if 2 <= $self->{'_debug'};
      }
    } # foreach line of query results HTML page
  if ($state ne $HITS)
    {
    # End, no other pages (missed some tag somewhere along the line)
    $self->{_next_url} = undef;
    }
  if (defined($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    }
  
  # Sleep so as to not overload Mr. HotBot
  $self->user_agent_delay if (defined($self->{_next_url}));
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__

Martin''s page download results, 1998-02:

simplest arbitrary page:
http://www.search.hotbot.com/hResult.html?MT=lsam+replication&DE=0&DC=100
http://www.search.hotbot.com/hResult.html?MT=Christie+Abbott&base=100&DC=100&DE=0&act.next.x=1

explanation of known fields on GUI search page:
date = (checkbox) filter by date
DC = (entry) number of hits per page
DE = (selection) output format
DV = (selection) date criteria
FRA = (checkbox) include audio data type
FSW = (checkbox) include shockwave data type
FVI = (checkbox) include image data type
FVV = (checkbox) include video data type
MT = query terms
RD = (checkbox) filter by location
RG = (selection) location criteria
SM = (selection) search type 
