#!/usr/local/bin/perl -w

# Metacrawler.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Metacrawler.pm,v 1.2 1999/07/13 17:08:57 mthurn Exp $

=head1 NAME

WWW::Search::Metacrawler - class for searching Metacrawler 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Metacrawler');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a Metacrawler specialization of WWW::Search.
It handles making and interpreting Metacrawler searches
F<http://www.metacrawler.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 
See $TEST_CASES below.

=head1 AUTHOR

As of 1998-02-02, C<WWW::Search::Metacrawler> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::Metacrawler> was originally written by Wm. L. Scheding,
based on C<WWW::Search::AltaVista>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 2.01

Code cleanup, no change in functionality.

=head2 1.17

Metacrawler changed their search script location and output format on 1998-05-21.
Also, as many as 6 fields of each SearchResult are now filled in.

=head2 1.13

Fixed the maximum_to_retrieve off-by-one problem.
Updated test cases.

=head2 1.12

Metacrawler does not do truncation. Therefore, if the query contains
truncation characters (i.e. '*' at end of words), they are simply
deleted before the query is sent to Metacrawler.

=head2 1.11

Fixed and revamped by Martin Thurn.  Sent to John Heidemann
(maintainer of WWW::Search) on 1998-02-05 for inclusion in the next
release of WWW::Search.

=cut

#  Test cases:
# '+mrfglbqnx +NoSuchWord'       ---   no URLs
# '"Christie Abbott"'            ---   16 URLs on one page
# '"Martin Thurn" AND Bible'     ---  141 URLs on two pages

#####################################################################

package WWW::Search::Metacrawler;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '2.01';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Metacrawler', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Metacrawler', '$MAINTAINER', 'one_page', '"Christie Abbott"', \$TEST_RANGE, 2,49);
&test('Metacrawler', '$MAINTAINER', 'two_page', '"Martin Thurn" AND Bible', \$TEST_GREATER_THAN, 87);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;
  # Why waste time sending so many queries?  Do a whole lot all at once!
  # 500 results take  70 seconds at 100 per page
  # 500 results take 234 seconds at  10 per page
  my $DEFAULT_HITS_PER_PAGE = 100;
  # $DEFAULT_HITS_PER_PAGE = 10;   # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;
  # $self->timeout(120);  # Metacrawler used to be notoriously slow

  # As of 1998-05, Metacrawler apparently doesn't like WWW::Search!  Response was
  # RC: 403 (Forbidden)
  # Message: Forbidden by robots.txt
  $self->user_agent(1);

  $self->{_next_to_retrieve} = 0;
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
                         'search_url' => 'http://www.metacrawler.com/crawler',  ## ALTERATION
                         'site' => 'www::search',  ## Paul Phillips of Metacrawler requested this option so he can track incoming traffic
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
  # Ugh!  Metacrawler chokes if our URL has a dangling '&' at the end:
  chop $options;
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
  # print STDERR " *   Metacrawler::native_retrieve_some()\n" if $self->{'_debug'};
  
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
    }

  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($TITLE, $HEADER, 
      $HITS, $HIT1, $HIT2, $HIT3, $HIT4, $HIT5,
      $NEXT, $TRAILER) = qw(TI HE HH H1 H2 H3 H4 H5 NX TR);
  my ($hits_found) = 0;
  my ($state) = ($TITLE);
  my ($hit) = ();
  my $sHitPattern = quotemeta '<font color="#000000">';  ## ALTERATION
  foreach ($self->split_lines($response->content())) 
    {
    s/\r$//;  # delete DOS carriage-return
    next if m/^\r?$/; # short circuit for blank lines
    print STDERR " * $state ===$_===" if 2 <= $self->{'_debug'};

    if ($state eq $TITLE && 
        m@\<TITLE>Metacrawler query:\s+(.+)\</TITLE>@i)  ## ALTERATION
      {
      # Actual line of input is:
      # <HEAD><TITLE>Metacrawler results: Christie Abbott (1+)</TITLE>
      print STDERR "title line\n" if 2 <= $self->{'_debug'};
      $state = $HEADER;
      } # We're in TITLE mode, and line has title

    elsif ($state eq $HEADER &&
		m@Collated\sResults:\s(\d+)\sto\s(\d+)\sof\s(\d+)\sreferences\.@i)   ## ALTERATION
      {
      # Actual line of input is:
      # 312 matches.</b>&nbsp;&nbsp;
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $NEXT;
      } # we're in HEADER mode, and line has number of results

    elsif ($state eq $HITS && 
           m/^$sHitPattern/)
           # m|\<B>(\d+)\.\s\<A\ .+?\</A>\ \<A\ HREF=\043([^\043]+)\043>(.+?)\</A>\</B>\<BR>(.+?)\<br>.+?(\d+)\%.+?(\d+)\ bytes.+?(\d\d\d\d/\d\d/\d\d)|i)
      {
      print STDERR "hit line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <font face="verdana&#44;arial&#44;helvetica" size="2"><B>1. <A HREF="http://www.toysrgus.com/images-bootleg.html" TARGET="preview"><IMG SRC="http://static.Metacrawler.com/images/btn.openpage.white.gif" BORDER="0" WIDTH="17" HEIGHT="16" ALT=""></A> <A HREF="http://www.toysrgus.com/images-bootleg.html">Bootlegs</A></B><BR>Bootlegs Maintained by Gus Lopez (lopez@cs.washington.edu) Bootlegs toys and other Star Wars collectibles were made primarily in countries where Star Wars was not commercially released in theaters. Most Star Wars bootlegs originate from the eastern.<br></font><font size="2">99%&nbsp;&nbsp; 5601 bytes&#44; 1998/03/19 &nbsp;&nbsp;&nbsp;http://www.toysrgus.com/images-bootleg.html</font><p>
      my ($iHit,$iPercent,$iBytes,$sURL,$sTitle,$sDesc,$sDate) = (0,0,0,'','','','');
      # m/\<B>(\d+)\.\s/ && $iHit = $1;
      ($sURL,$sTitle) = ($1,$2) if m|\<A\sHREF=\042([^\042]+)\042>(.+?)\</A>|;
      $sDesc = $1 if m/\<BR>(.+)\<br>/;
      ($iPercent,$iBytes,$sDate) = ($1,$2,$3) if m|>(\d+)\%&nbsp;&nbsp;\s(\d+)\sbytes&\#44;\s(\d\d\d\d/\d\d/\d\d)|;
      # At this point, we could do something about "mirror" URLs (like
      # ignore them), but then our total hit count will get all out of
      # whack...?
      if (ref($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      if ($sURL eq '')
        {
        print STDERR " *** parse error: found hit line but no URL\n" if 2 <= $self->{'_debug'};
        }
      else
        {
        $hit = new WWW::SearchResult;
        $hit->add_url($sURL);
        $hit->title($sTitle) if $sTitle ne '';
        $hit->description($sDesc) if $sDesc ne '';
        $hit->score($iPercent) if 0 < $iPercent;
        $hit->size($iBytes) if 0 < $iBytes;
        $hit->change_date($sDate) if $sDate ne '';
        $self->{'_num_hits'}++;
        $hits_found++;
        }
      $state = $HITS;
      } # $state eq HIT2

    elsif ($state eq $NEXT && m|\</form>|i)
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
      # Ugh!  Metacrawler chokes if our URL has a dangling '&' at the end:
      chop $options;
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
  
  # Sleep so as to not overload Mr. Metacrawler
  $self->user_agent_delay if (defined($self->{_next_url}));
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__
