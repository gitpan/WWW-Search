#!/usr/local/bin/perl -w

# HotBot.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: HotBot.pm,v 1.14 1998/11/07 01:26:09 johnh Exp $

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
terms: 

  $oSearch->native_query(escape_query('Dorothy Oz'));

If you want "all of", call native_query like this:

  $oSearch->native_query(escape_query('Dorothy Oz'), {'SM' => 'MC'});

If you want to send HotBot a boolean phrase, call native_query like this:

  $oSearch->native_query(escape_query('Oz AND Dorothy NOT Australia'), {'SM' => 'B'});

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

=head1 CAVEATS

When www.hotbot.com reports a "Mirror" URL, WWW::Search::HotBot
ignores it.  Therefore, the number of URLs returned by
WWW::Search::HotBot might not agree with the value returned in
approximate_result_count.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

  Test cases (accurate as of 1998-11-06):

    $file = 'test/HotBot/zero_result';
    $query = 'Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/HotBot/one_page_result';
    $query = '"Chris'.'tie Abb'.'ott"';
    test($mode, $TEST_RANGE, 2, 99);

    $file = 'test/HotBot/multi_page_result';
    $query = 'Moth'.'ma';
    test($mode, $TEST_GREATER_THAN, 100);

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

=head2 1.27, 1998-11-06

HotBot changed their output format(?).
HotBot.pm now uses hotbot.com's text-only search results format.
Minor documentation changes.

=head2 1.25, 1998-09-11

HotBot changed their output format ever so slightly.
Documentation added for all possible HotBot query options!

=head2 1.23

Better documentation for boolean queries.  (Thanks to Jason Titus jason_titus@odsnet.com)

=head2 1.22

www.hotbot.com changed their output format.

=head2 1.21

www.hotbot.com changed their output format.

=head2 1.20

\n changed to \012 for MacPerl compatibility

=head2 1.17

www.hotbot.com changed their search script location and output format on 1998-05-21.
Also, as many as 6 fields of each SearchResult are now filled in.

=head2 1.13

Fixed the maximum_to_retrieve off-by-one problem.
Updated test cases.

=head2 1.12

www.hotbot.com does not do truncation. Therefore, if the query
contains truncation characters (i.e. '*' at end of words), they are
simply deleted before the query is sent to www.hotbot.com.

=head2 1.11 1998-02-05

Fixed and revamped by Martin Thurn.  

=cut

#####################################################################

package WWW::Search::HotBot;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.27';

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
  $DEFAULT_HITS_PER_PAGE = 10 if $self->{_debug};
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;
  # $self->timeout(120);  # HotBot used to be notoriously slow

  # As of 1998-05, HotBot apparently doesn't like WWW::Search!  When
  # using user_agent(0), response was "RC: 403 (Forbidden) Message:
  # Forbidden by robots.txt"
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
                         'search_url' => 'http://www.hotbot.com/text/default.asp',
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
  
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  
  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  
  # print STDERR " * search_from_file is set!\n" if $self->{search_from_file};
  # print STDERR " * search_to_file is set!\n" if $self->{search_to_file};
  # Get some results
  print STDERR "\n *   sending request (",$self->{_next_url},")" if $self->{'_debug'};
  my($response) = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    };

  print STDERR "\n *   got response" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($TITLE, $HEADER, 
      $HITS, $HIT1, $HIT2, $HIT3, $HIT4, $HIT5,
      $NEXT, $TRAILER) = qw(TI HE HH H1 H2 H3 H4 H5 NX TR);
  my ($hits_found) = 0;
  my ($state) = ($TITLE);
  my ($hit) = ();
  my $sHitPattern = quotemeta '<font face="verdana&#44;arial&#44;helvetica" size="2">';
  foreach ($self->split_lines($response->content()))
    {
    s/\r$//;  # delete DOS carriage-return
    next if m/^\r?$/; # short circuit for blank lines
    print STDERR "\n * $state ===$_===" if 2 <= $self->{'_debug'};

    if ($state eq $TITLE && 
        m@<TITLE>HotBot results:\s+(.+)\s\(\d+\+\)</TITLE>@i) 
      {
      # Actual line of input is:
      # <HEAD><TITLE>HotBot results: Christie Abbott (1+)</TITLE>
      print STDERR "title line" if 2 <= $self->{'_debug'};
      $state = $HEADER;
      } # We're in TITLE mode, and line has title

    elsif ($state eq $HEADER && 
           m{^(\d+)\s+matches.<})
      {
      # Actual line of input is:
      # 248 matches.</b><br>
      print STDERR "count line" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $NEXT;
      } # we're in HEADER mode, and line has number of results

    elsif ($state eq $NEXT && m|href="[^"?]+\?([^"]+act\.next=next[^"]+)|)
      {
      print STDERR " found next button" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      $self->{_next_url} = $self->{'_options'}{'search_url'} .'?'. $1;
      print STDERR "\n + next_url is >>>", $self->{_next_url}, "<<<" if $self->{_debug};
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $state = $HITS;
      } # found "next" link in NEXT mode
    elsif ($state eq $NEXT && m|^<B>(\d+)\.| )
      {
      print STDERR " no next button; " if 2 <= $self->{'_debug'};
      # There was no "next" button on this page; no more pages to get!
      $self->{'_next_url'} = undef;
      $state = $HITS;
      # Fall through (i.e. don't say "elsif") so that the $HITS
      # pattern matches this line (again)!
      }

    if ($state eq $HITS && m|^<B>(\d+)\.| )
      {
      print STDERR "hit line" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <B>2. </B><A HREF="http://www.toysrgus.com/textfiles.html">Charts, Tables, and Text Files</A><BR>Text Files Maintained by Gus Lopez (lopez@halcyon.com) Ever wonder which weapon goes with which figure? Well, that's the kind of information you can find right here. Any beginning collector should glance at some of these files since they answer...<br>92%&nbsp;&nbsp;&nbsp; 3616 bytes&#44; 1998/04/07&nbsp;&nbsp;&nbsp;http://www.toysrgus.com/textfiles.html<p>
      my ($iHit,$iPercent,$iBytes,$sURL,$sTitle,$sDesc,$sDate) = (0,0,0,'','','','');
      # m/<B>(\d+)\.\s/ && $iHit = $1;
      $sURL = $1 if m/HREF="([^"]+)/;
      $sTitle = $1 if m|>([^<]+)</A>|;
      $sDate = $1 if m/(\d\d\d\d\/\d\d\/\d\d)&nbsp;/;
      $sDesc = $1 if m/<BR>(.+)<br>/;
      $iPercent = $1 if m/>(\d+)\%(&nbsp;|<)/;
      $iBytes = $1 if m/&nbsp;\s(\d+)\sbytes/;
      # Note that we ignore MIRROR URLs, so our total hit count may
      # get all out of whack.
      if ($sURL eq '')
        {
        print STDERR "\n *** parse error: found hit line but no URL\n" if 2 <= $self->{'_debug'};
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

text-only pages:
http://www.hotbot.com/text/default.asp?SM=MC&MT=Martin+Thurn&DC=100&DE=2&DV=0&RG=all&LG=any&_v=2&OPs=MDRTP&NUMMOD=2

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
