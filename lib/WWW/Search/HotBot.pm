#!/usr/local/bin/perl -w

# HotBot.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: HotBot.pm,v 1.13 1998/09/11 20:20:45 johnh Exp $

=head1 NAME

WWW::Search::HotBot - class for searching HotBot 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('HotBot');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a HotBot specialization of WWW::Search.
It handles making and interpreting HotBot searches
F<http://www.hotbot.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

The default behavior is for HotBot to look for "any of" the query
terms.  If you want "all of", call native_query like this:

  $oSearch->native_query(escape_query('Dorothy Toto Oz'), {'SM' => 'MC'});

If you want to send HotBot a boolean phrase, call native_query like this:

  $oSearch->native_query(escape_query('Oz AND Dorothy AND toto NOT Australia'), {'SM' => 'B'});

See below for other query-handling options.

=head1 OPTIONS

The following search options can be activated by sending a hash as the
second argument to native_query().

=head2 Format / Treatment of Query Terms

The default is logical OR of all the query terms.

=over 2

=item   {'SM' => 'MC'}

"Must Contain": logical AND of all the query terms.

=item   {'SM' => 'SC'}

"Should Contain": logical OR of all the query terms.
This is the default.

=item   {'SM' => 'B'}

"Boolean": the entire query is treated as a boolean expression with
AND, OR, NOT, and parentheses.

=item   {'SM' => 'name'}

The entire query is treated as a person's name.

=item   {'SM' => 'phrase'}

The entire query is treated as a phrase.

=item   {'SM' => 'title'}

The query is applied to the page title.  (I assume the logical OR of
the query terms will be applied to the page title.)

=item   {'SM' => 'url'}

The query is assumed to be a URL, and the results will be pages that
link to the query URL.

=back

=head2 Restricting Search to a Date Range

The default is no date restrictions.

=over 2

=item {'date' => 'within', 'DV' => 90}

Only return pages updated within 90 days of today.  
(Substitute any integer in place of 90.)

=item {'date' => 'range', 'DR' => 'After', 'DY' => 97, 'DM' => 12, 'DD' => 25}

Only return pages updated after Christmas 1997.
(Substitute any year, month, and day for 97, 12, 25.)

=item {'date' => 'range', 'DR' => 'Before', 'DY' => 97, 'DM' => 12, 'DD' => 25}

Only return pages updated before Christmas 1997.
(Substitute any year, month, and day for 97, 12, 25.)

=back

=head2 Restricting Search to a Geographic Area

The default is no restriction to geographic area.

=over 2

=item {'RD' => 'AN'}

Return pages from anywhere.  This is the default.

=item {'RD' => 'DM', 'Domain' => 'microsoft.com, .cz'}

Restrict search to pages located in the listed domains.
(Substitute any list of domain substrings.)

=item {'RD' => 'RG', 'RG' => '.com'}

Restrict search to North American commercial web sites.

=item {'RD' => 'RG', 'RG' => '.edu'}

Restrict search to North American educational web sites.

=item {'RD' => 'RG', 'RG' => '.gov'}

Restrict search to United Stated Government web sites.

=item {'RD' => 'RG', 'RG' => '.mil'}

Restrict search to United States military commercial web sites.

=item {'RD' => 'RG', 'RG' => '.net'}

Restrict search to North American '.net' web sites.

=item {'RD' => 'RG', 'RG' => '.org'}

Restrict search to North American organizational web sites.

=item {'RD' => 'RG', 'RG' => 'NA'}

"North America": Restrict search to all of the above types of web sites.

=item {'RD' => 'RG', 'RG' => 'AF'}

Restrict search to web sites in Africa.

=item {'RD' => 'RG', 'RG' => 'AS'}

Restrict search to web sites in India and Asia.

=item {'RD' => 'RG', 'RG' => 'CA'}

Restrict search to web sites in Central America.

=item {'RD' => 'RG', 'RG' => 'DU'}

Restrict search to web sites in Oceania.

=item {'RD' => 'RG', 'RG' => 'EU'}

Restrict search to web sites in Europe.

=item {'RD' => 'RG', 'RG' => 'ME'}

Restrict search to web sites in the Middle East.

=item {'RD' => 'RG', 'RG' => 'SE'}

Restrict search to web sites in Southeast Asia.

=back

=head2 Requesting Certain Multimedia Data Types

The default is not specifically requesting any multimedia types
(presumably, this will NOT restrict the search to NON-multimedia
pages).

=over 2

=item {'FAC' => 1}

Return pages which contain Adobe Acrobat PDF data.

=item {'FAX' => 1}

Return pages which contain ActiveX.

=item {'FJA' => 1}

Return pages which contain Java.

=item {'FJS' => 1}

Return pages which contain JavaScript.

=item {'FRA' => 1}

Return pages which contain audio.

=item {'FSU' => 1, 'FS' => '.txt, .doc'}

Return pages which have one of the listed extensions.
(Substitute any list of DOS-like file extensions.)

=item {'FSW' => 1}

Return pages which contain ShockWave.

=item {'FVI' => 1}

Return pages which contain images.

=item {'FVR' => 1}

Return pages which contain VRML.

=item {'FVS' => 1}

Return pages which contain VB Script.

=item {'FVV' => 1}

Return pages which contain video.

=back

=head2 Requesting Pages at Certain Depths on Website

The default is pages at any level on their website.

=over 2

=item {'PS'=>'A'}

Return pages at any level on their website.
This is the default.

=item {'PS' => 'D', 'D' => 3 }

Return pages within 3 links of "top" page of their website.
(Substitute any integer in place of 3.)

=item {'PS' => 'F'}

Only return pages that are the "top" page of their website.

=back

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
C<{cache}>.  If it finds a ''next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we''re done.

=head1 CAVEATS

When HotBot reports a "Mirror" URL, WWW::Search::HotBot ignores it.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

  Test cases (results as of 1998-08-27):
  '+mrfglbqnx +NoSuchWord'       ---   no URLs
  '"Christie Abbott"'            ---    9 URLs on one page
  'LSAM'                         ---  184 URLs on two pages

=head1 AUTHOR

As of 1998-02-02, C<WWW::Search::HotBot> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::HotBot> was originally written by Wm. L. Scheding,
based on C<WWW::Search::AltaVista>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 1.25 1998-09-11

HotBot changed their output format ever so slightly.
Documentation added for all possible HotBot query options!

=head2 1.23

Better documentation for boolean queries.  (Thanks to Jason Titus jason_titus@odsnet.com)

=head2 1.22

HotBot changed their output format.

=head2 1.21

HotBot changed their output format.

=head2 1.20

\n changed to \012 for MacPerl compatibility

=head2 1.17

HotBot changed their search script location and output format on 1998-05-21.
Also, as many as 6 fields of each SearchResult are now filled in.

=head2 1.13

Fixed the maximum_to_retrieve off-by-one problem.
Updated test cases.

=head2 1.12

HotBot does not do truncation. Therefore, if the query contains
truncation characters (i.e. '*' at end of words), they are simply
deleted before the query is sent to HotBot.

=head2 1.11 1998-02-05

Fixed and revamped by Martin Thurn.  

=cut

#####################################################################

package WWW::Search::HotBot;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# private
sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;

  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} ||= 0;

  # Why waste time sending so many queries?  Do a whole lot all at once!
  # 500 results take  70 seconds at 100 per page
  # 500 results take 234 seconds at  10 per page
  my $DEFAULT_HITS_PER_PAGE = 100;
  # $DEFAULT_HITS_PER_PAGE = 10; # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;
  # $self->timeout(120);  # HotBot used to be notoriously slow

  # As of 1998-05, HotBot apparently doesn't like WWW::Search!  When
  # using user_agent(0), response was RC: 403 (Forbidden) Message:
  # Forbidden by robots.txt
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
                         'search_url' => 'http://www.hotbot.com/default.asp',
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
    # If we want to let the user delete options, do the
    # following. (They can still blank them out, which may or may not
    # have the same effect, anyway):
    # next unless $options_ref->{$_} ne '';
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  # Ugh!  HotBot chokes if our URL has a dangling '&' at the end:
  chop $options;
  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  # print STDERR " *   HotBot::native_retrieve_some()\n" if $self->{'_debug'};
  
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  
  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  
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
  my $sHitPattern = quotemeta '<font face="verdana&#44;arial&#44;helvetica" size="2">';
  foreach (split(/\012/, $response->content())) 
    {
    s/\r$//;  # delete DOS carriage-return
    next if m/^\r?$/; # short circuit for blank lines
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
          m{Web\sResults})
      {
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $state = $NEXT;
      }

    elsif ($state eq $NEXT && m|</form>|i)
      {
      print STDERR " no next button\n" if 2 <= $self->{'_debug'};
      # There was no "next" button on this page; no more pages to get!
      $self->{'_next_url'} = undef;
      $state = $HITS;
      }
    elsif ($state eq $NEXT && m|act\.next\.x|)
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
      # Ugh!  HotBot chokes if our URL has a dangling '&' at the end:
      chop $options;
      # Finally figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $state = $HITS;
      }

    elsif ($state eq $HITS && 
           m{&nbsp;(\d+)&nbsp;matches</font>})
      {
      # Actual line of input is:
      # <font face="Verdana, Arial, Helvetica" size="2" color="#000000"><b>Martin THurn:</b>&nbsp;&nbsp;1009435&nbsp;matches</font><br>
      print STDERR "count line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in HITS mode, and line has number of results

    elsif ($state eq $HITS && 
           m|^<[^>]*><B>(\d+)\.| )
           # m/^$sHitPattern/)
           # m|<B>(\d+)\.\s<A\ .+?</A>\ <A\ HREF=\043([^\043]+)\043>(.+?)</A></B><BR>(.+?)<br>.+?(\d+)\%.+?(\d+)\ bytes.+?(\d\d\d\d/\d\d/\d\d)|i)
      {
      print STDERR "hit line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <font face="verdana&#44;arial&#44;helvetica" size="2"><B>1. <A HREF="http://www.toysrgus.com/images-bootleg.html" TARGET="preview"><IMG SRC="http://static.hotbot.com/images/btn.openpage.white.gif" BORDER="0" WIDTH="17" HEIGHT="16" ALT=""></A> <A HREF="http://www.toysrgus.com/images-bootleg.html">Bootlegs</A></B><BR>Bootlegs Maintained by Gus Lopez (lopez@cs.washington.edu) Bootlegs toys and other Star Wars collectibles were made primarily in countries where Star Wars was not commercially released in theaters. Most Star Wars bootlegs originate from the eastern.<br></font><font size="2">99%&nbsp;&nbsp; 5601 bytes&#44; 1998/03/19 &nbsp;&nbsp;&nbsp;http://www.toysrgus.com/images-bootleg.html</font><p>
      my ($iHit,$iPercent,$iBytes,$sURL,$sTitle,$sDesc,$sDate) = (0,0,0,'','','','');
      # m/<B>(\d+)\.\s/ && $iHit = $1;
      $sURL = $1 if m/target=([^&"]+)/;
      $sTitle = $1 if m|>([^<]+)</A>|;
      $sDesc = $1 if m/<BR>(.+)<br>/;
      $iPercent = $1 if m|>(\d+)\%<|;
      # Note that we ignore MIRROR URLs, so our total hit count may
      # get all out of whack.
      if ($sURL eq '')
        {
        print STDERR " *** parse error: found hit line but no URL\n" if 2 <= $self->{'_debug'};
        }
      else
        {
        if (ref($hit))
          {
          push(@{$self->{cache}}, $hit);
          } # if
        $hit = new WWW::SearchResult;
        $hit->add_url($sURL);
        $hit->title($sTitle) if $sTitle ne '';
        $hit->description($sDesc) if $sDesc ne '';
        $hit->score($iPercent) if 0 < $iPercent;
        $hit->size($iBytes) if 0 < $iBytes;
        $hit->change_date($sDate) if $sDate ne '';
        $self->{'_num_hits'}++;
        $hits_found++;
        } # if $URL else
      $state = $HITS;
      } # $state eq HITS

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

Martin''s page download results, 1998-02:

simplest arbitrary page:
http://www.search.hotbot.com/hResult.html?MT=lsam+replication&DE=0&DC=100
http://www.search.hotbot.com/hResult.html?MT=Christie+Abbott&base=100&DC=100&DE=0&act.next.x=1

explanation of known fields on GUI search page:
date = (checkbox) filter by date
     within = restrict to within DV days before today
     range = anchor date filter according to the date given in DR
DV = (selection) date (age) criteria
     0 = no date restriction
     <integer x> = restrict to within x days before today
DR = (selection) date anchor criteria
     Before = only return pages updated before the date given in DY,DM,DD
     After = only return pages updated after the date given in DY,DM,DD
DY = two-digit year (1998 = 98)
DM = month (January = 1)
DD = day of month
DC = (entry) number of hits per page
DE = (selection) output format
     2 = the only value WWW::Search::HotBot can recognize!
FAX = (checkbox) only return pages that contain ActiveX data type
FJA = (checkbox) only return pages that contain Java data type
FJS = (checkbox) only return pages that contain JavaScript data type
FRA = (checkbox) only return pages that contain audio data type
FSU = (checkbox) only return pages whose name ends with extension(s) given in FS
FS = (text) file extensions for user-defined page-type selection (space-delimited)
FSW = (checkbox) only return pages that contain ShockWave data type
FVI = (checkbox) only return pages that contain image data type
FVR = (checkbox) only return pages that contain VRML data type
FVV = (checkbox) only return pages that contain video data type
MT = query terms
PS = (selection) depth of return page location on its website
     A = any page on site
     D = returned pages must be within PD (below) links of the top
     F = returned pages must be "top" page of website
     HP = personal pages (not implemented)
D = (integer) page depth for PS=D
RD = (checkbox) filter by location
     AN = return pages from anywhere
     DM = return pages whose URL ends with string given in Domain (below)
     RG = filter according to value of RG
Domain = (text) URL endings for user-defined location selection (space-delimited)
     for example "microsoft.com" ".cz"
RG = (selection) location criteria
     .com = North America (.com)
     .net = North America (.net)
     .edu = North America (.edu)
     .org = North America (.org)
     .gov = North America (.gov)
     .mil = North America (.mil)
     NA = North America (all)
     EU = Europe
     SE = Southeast Asia
     AS = India & Asia
     SA = South America
     DU = Oceania
     AF = Africa
     ME = Middle East
     CA = Central America
SM = (selection) search type 
     MC = all the words
     SC = any of the words
     phrase = exact phrase
     title = the page title
     name = the person
     url = links to this URL
     B = Boolean phrase     
