# HotBot.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: HotBot.pm,v 1.43 1999/11/12 15:32:39 mthurn Exp $

=head1 NAME

WWW::Search::HotBot - backend for searching www.hotbot.com

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

=item {'date' => 'range', 'DR' => 'newer', 'DY' => 97, 'DM' => 12, 'DD' => 25}

Only return pages updated after Christmas 1997.
(Substitute any year, month, and day for 97, 12, 25.)

=item {'date' => 'range', 'DR' => 'older', 'DY' => 97, 'DM' => 12, 'DD' => 25}

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
See $TEST_CASES below.

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

=head2 2.07, 1999-11-12

BUGFIX for domain-limited URL parsing (thanks to Leon Brocard)

=head2 2.06, 1999-10-18

www.hotbot.com changed their output format slightly;
now uses strip_tags() on title and description

=head2 2.05, 1999-10-05

now uses hash_to_cgi_string(); new test cases

=head2 2.03, 1999-09-28

BUGFIX: was missing the "Next page" link sometimes.

=head2 2.02, 1999-08-17

Now is able to parse "URL-only" format (i.e. {'DE' => 0}) and "brief
description" format (i.e. {'DE' => 1}) if the user so desires.

=head2 1.34, 1999-07-01

New test cases.

=head2 1.32, 1999-06-20

Now unescapes the URLs before returning them.

=head2 1.31, 1999-06-11

www.hotbot.com changed their output format ever so slightly.  (Thanks
to Jim jsmyser@bigfoot.com for pointing it out)

=head2 1.30, 1999-04-12

BUG FIX: results for domain-limited search were not parsed.  (Thanks to
Christopher York yorkc@ccwf.cc.utexas.edu for pointing it out)

=head2 1.29, 1999-02-22

www.hotbot.com changed their output format.  (Thanks to Tim Chklovski
timc@mit.edu for pointing it out)

=head2 1.27, 1998-11-06

HotBot changed their output format(?).
HotBot.pm now uses hotbot.com's text-only search results format.
Minor documentation changes.

=head2 1.25, 1998-09-11

HotBot changed their output format ever so slightly.
Documentation added for all known HotBot query options!

=head2 1.23

Better documentation for boolean queries.  (Thanks to Jason Titus jason_titus@odsnet.com)

=head2 1.22

www.hotbot.com changed their output format.

=head2 1.21

www.hotbot.com changed their output format.

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

=head2 1.11, 1998-02-05

Fixed and revamped by Martin Thurn.  

=cut

#####################################################################

package WWW::Search::HotBot;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '2.07';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('HotBot', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('HotBot', '$MAINTAINER', 'one', 'LSAM replication', \$TEST_RANGE, 2,80);
&test('HotBot', '$MAINTAINER', 'two', 'Calri'.'ssian', \$TEST_GREATER_THAN, 101);
ENDTESTCASES

use Carp ();
use WWW::Search qw( generic_option strip_tags );
require WWW::SearchResult;
use URI::Escape;

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
  # $DEFAULT_HITS_PER_PAGE = 10 if $self->{_debug};
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

  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $self->hash_to_cgi_string($options_ref);
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
  my $WHITESPACE = '(\s|&nbsp;)';
  foreach ($self->split_lines($response->content()))
    {
    s/\r$//;  # delete DOS carriage-return
    next if m/^\r?$/; # short circuit for blank lines
    print STDERR "\n * $state ===$_===" if 2 <= $self->{'_debug'};

    # \074 is <
    # \076 is >
    if ($state eq $TITLE && 
        m@\074TITLE\076HotBot results:\s+(.+)\s\(\d+\+\)\074/TITLE\076@i) 
      {
      # Actual line of input is:
      # <HEAD><TITLE>HotBot results: Christie Abbott (1+)</TITLE>
      print STDERR "title line" if 2 <= $self->{'_debug'};
      $state = $HEADER;
      } # We're in TITLE mode, and line has title

    elsif ($state eq $HEADER && 
           m!(?:\s|\&nbsp\;)([\d,]+)(?:\s|\&nbsp\;)+Matches.!i)
      {
      # Actual line of input is:
      # <b>Returned:&nbsp;69&nbsp;Matches&nbsp;
      my $iCount = $1;
      $iCount =~ s/\D//g;
      print STDERR "count line ($iCount) " if 2 <= $self->{'_debug'};
      $self->approximate_result_count($iCount);
      $state = $NEXT;
      } # we're in HEADER mode, and line has number of results

    elsif ($state eq $NEXT && m|href="[^"?]+\?([^"]*act\.next=next[^"]+)|)
      {
      # Actual line of input:
      #        <b>1&nbsp;-&nbsp;100&nbsp;</b><a href="/text/results.asp?act.next=next&MT=IG%2D88&SM=SC&DC=100&BT=T">next</a><font color="#FF0000" face="courier" size=1>&nbsp;<b>&gt;&gt;</b></font>
      print STDERR " found next button" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      $self->{_next_url} = $self->{'_options'}{'search_url'} .'?'. $1;
      print STDERR "\n + next_url is >>>", $self->{_next_url}, "<<<" if $self->{_debug};
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $state = $HITS;
      } # found "next" link in NEXT mode
    elsif ($state eq $NEXT && m|^\074p\076\s\074b\076(\d+)\.| )
      {
      print STDERR " no next button; " if 2 <= $self->{'_debug'};
      # There was no "next" button on this page; no more pages to get!
      $self->{'_next_url'} = undef;
      $state = $HITS;
      # Fall through (i.e. don't say "elsif") so that the $HITS
      # pattern matches this line (again)!
      }

    if ($state eq $HITS && m|^\074p\076\s\074b\076(\d+)\.| )
      {
      print STDERR "multihit line" if 2 <= $self->{'_debug'};
      # Actual line of input as of 1999-10-18:
      # <p> <b>10.&nbsp;&nbsp;<a href=/director.asp?target=http%3A%2F%2Fwww%2E5ss%2Ecom%2Fswafw%2Finfo%2Ffaq%2Ehtml&id=10&userid=4owy5fprDDg/&query=MT=%22Martin+Thurn%22&SM=SC&DC=100&BT=T&rsource=INK>http://www.5ss.com/swafw/info/faq.html</A></b><br>REC.ARTS.SF.STARWARS.COLLECTING FAQ Last updated 4-22-97 ** Coordinators: Paul Levesque (paulleve@map.com) Gus Lopez (lopez@cs.washington.edu) Chris Nichols (anichols@bucknell.edu) Authors: Dave Halsted (def@leland.stanford.edu) Gus Lopez  (lopez..<br><font size=1><b>85%&nbsp&nbsp</b><i>8/27/97</i>  http://www.5ss.com/swafw/info/faq.html<BR>See results from <a href="/?MT=%22Martin+Thurn%22&SM=SC&DC=100&RD=DM&Domain=www%2E5ss%2Ecom&BT=T">this site only</a>.</font>
      # Here is what it looks like if DE=1 (brief description):
      # <p> <b>1. <a href=/director.asp?target=http%3A%2F%2Fwww%2Epitt%2Eedu%2F%7Ethurn&id=1&userid=3gr+hc5jrHwm&query=MT=Martin+Thurn&SM=SC&DE=1&DC=100&rsource=INK>Martin Thurn's Index Page</A></b><br>Martin Thurn Why am I so busy? I am gainfully employed at TASC. I have a family including 3 beautiful children. I am a co-habitant with two immaculate cats. I am the editor of The Star Wars Collector, a bimonthly newsletter by Star Wars  collectors.<font size=1><br><b>99%&nbsp&nbsp</b></font><p> <b>2. <a href=/director.asp?target=http%3A%2F%2Fwww%2Eposta%2Esuedtirol%2Ecom%2F&id=2&userid=3gr+hc5jrHwm&query=MT=Martin+Thurn&SM=SC&DE=1&DC=100&rsource=INK>**Gasthof Post St. Martin in Thurn Val Badia Sudtirol Alto Adige Southtyrol Suedtirol</A></b><br>Urlaub im Gasthof Post in Pikolein in St. Martin in Thurn in Val Badia in  Sudtiro<font size=1><br><b>98%&nbsp&nbsp</b></font><p> <b>3. ...
      my @asHits = split /\074p\076/;
      foreach my $sHit (@asHits)
        {
        my ($iHit,$iPercent,$iBytes,$sURL,$sTitle,$sDesc,$sDate) = (0,0,0,'','','','');
        # m/<b>(\d+)\.$WHITESPACE/ && $iHit = $1;
        $sURL = $1 if $sHit =~ m/uHost=(.+)\"/;
        # Following line corrected 1999-11-11 to ignore domain-limited link (by Leon Brocard)
        $sURL ||= $1 if $sHit =~ m!\074/i\076\s*(.+?)\074!;
        # Following line added 1999-08-17 to recognize brief-description results (DE=1):
        $sURL ||= $1 if $sHit =~ m!director.asp\?target=(.+?)\&!;
        $sTitle = &strip_tags($1) if $sHit =~ m/\076([^\074]+)\074\/A\076/;
        $sDate = $1 if $sHit =~ m!\074i\076(\d\d?\/\d\d?\/\d\d)\074/i\076!;
        $sDesc = &strip_tags($1) if $sHit =~ m/\074br\076([^\074]+)\074(br|font)/;
        $iPercent = $1 if $sHit =~ m/\076(\d+)\%(&nbsp|\074)/;
        $iBytes = $1 if $sHit =~ m/&nbsp;\s(\d+)\sbytes/;
        # Note that we ignore MIRROR URLs, so our total hit count may
        # get all out of whack.
        if ($sURL ne '')
          {
          if (ref($hit))
            {
            push(@{$self->{cache}}, $hit);
            } # if
          $hit = new WWW::SearchResult;
          # As of 1999-06-20: www.hotbot.pm escapes the URL on this line of output:
          print STDERR " +   raw       URL is $sURL...\n" if 5 <= $self->{'_debug'};
          $hit->add_url(uri_unescape($sURL));
          print STDERR " +   unescaped URL is $sURL...\n" if 5 <= $self->{'_debug'};
          $hit->title($sTitle) if $sTitle ne '';
          $hit->description($sDesc) if $sDesc ne '';
          $hit->score($iPercent) if 0 < $iPercent;
          $hit->size($iBytes) if 0 < $iBytes;
          $hit->change_date($sDate) if $sDate ne '';
          $self->{'_num_hits'}++;
          $hits_found++;
          } # if $URL else
        } # foreach
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
     older = only return pages updated before the date given in DY,DM,DD
     newer = only return pages updated after the date given in DY,DM,DD
DY = two-digit year (1998 = 98)
DM = month (January = 1)
DD = day of month
DC = (entry) number of hits per page
DE = (selection) output format
     0 = "URL only" (also gives title and score)
     1 = brief descriptions (adds description)
     2 = full descriptions (adds date and size)
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

Here is 
