# Dejanews.pm
# Copyright (C) 1998 by Martin Thurn
# $Id: Dejanews.pm,v 1.15 1999/12/10 15:38:48 mthurn Exp $

=head1 NAME

WWW::Search::Dejanews - class for searching Dejanews 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Dejanews');
  my $sQuery = WWW::Search::escape_query("sushi restaurant Columbus Ohio",);
  $oSearch->native_query($sQuery,
                         {'defaultOp' => 'AND'});
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a Dejanews specialization of WWW::Search.
It handles making and interpreting Dejanews searches
F<http://www.deja.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

Dejanews DOES support wildcards (asterisk at end of word).

The default behavior is the OR of the query terms.  If you want AND,
insert 'AND' between all the query terms in your query string:

  $oSearch->native_query(escape_query('Dorothy AND Toto AND Oz'));

or call
native_query like this:

  $oSearch->native_query(escape_query('Dorothy Toto Oz'), {'defaultOp' => 'AND'} );

The URLs returned point to "text only" articles from Dejanews' server.

If you want to search particular fields, add the escaped query for
each field to the second argument to native_query (sorry, this has not
been tested):

  $oSearch->native_query($sQuery, 
                         {'groups'   => 'comp.lang.perl.misc',
                          'subjects' => 'WWW::Search',
                          'authors'  => 'thurn',
                          'fromdate' => 'Jan 1 1997',
                          'todate'   => 'Dec 31 1997', } );

=head1 NOTES

In the SearchResults, the description field contains the forum name
and author's name (as reported by www.deja.com) in the following
format: "Newsgroup: comp.lang.perl; Author: Martin Thurn"

=head1 CAVEATS

Names of newsgroups ("forums") are unceremoniously truncated to 21
characters by www.deja.com.

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 
See $TEST_CASES below.

=head1 AUTHOR

C<WWW::Search::Dejanews> is maintained by Martin Thurn
(MartinThurn@iname.com); 
original version for WWW::Search by Cesare Feroldi de Rosa (C.Feroldi@it.net).

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

=head2 2.06, 1999-12-07

new test cases, pod update, ignore deja links, etc.

=head2 2.04, 1999-12-06

handle www.deja.com's new output format

=head2 2.03, 1999-10-05

now uses hash_to_cgi_string()

=head2 2.02, 1999-09-17

BUGFIX: was returning "power search" link (thanks to Jim Smyser for noticing)

=head2 2.01, 1999-07-13

=head2 1.12, 1999-07-06

Finally moved from www.dejanews.com to www.deja.com;
New test suite mechanism;

=head2 1.11, 1998-12-03

Now uses the split_lines() function;
sync with WWW::Search distribution's version number

=head2 1.4, 1998-08-27

New Dejanews.com output format

=head2 1.3, 1998-08-20

New Dejanews.com output format

=head2 1.2

First publicly-released version.

=cut

#####################################################################

package WWW::Search::Dejanews;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '2.06';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Dejanews', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Dejanews', '$MAINTAINER', 'one', 'irov'.'er', \$TEST_RANGE, 2,99);
&test('Dejanews', '$MAINTAINER', 'two', 'L'.'ili AND Le'.'dy', \$TEST_RANGE, 101,199);
&test('Dejanews', '$MAINTAINER', 'three', 'Jabb'.'a', \$TEST_GREATER_THAN, 201);
ENDTESTCASES

# private
sub native_setup_search
  {
  my ($self, $native_query, $rhOptions) = @_;

  my $DEFAULT_HITS_PER_PAGE = 100;
  # $DEFAULT_HITS_PER_PAGE = 10;  # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  $self->{agent_e_mail} = 'MartinThurn@iname.com';
  $self->user_agent(0);

  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options})) 
    {
    # These are the defaults:
    $self->{_options} = {
                         'search_url' => 'http://www.deja.com/qs.xp',
                         'LNG' => 'ALL',
                         'OP' => 'dnquery.xp',
                         'QRY' => $native_query,
                         'ST' => 'PS',
                         'defaultOp' => 'OR',
                         'maxhits' => $self->{'_hits_per_page'},
                         'showsort' => 'score',
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

  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $self->hash_to_cgi_string($self->{_options});

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
  my $response = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    };

  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($START, $HEADER, $HITS, $URL,$TITLE,$DATE,$FORUM,$AUTHOR, $TRAILER, $ALLDONE) = qw( ST HE HI UR TI DA FO AU TR AD );
  my $hits_found = 0;
  my $state = $START;
  my $hit;
  my $sDate = '';
  # The fields of each record appear in the following order: DATE, URL, TITLE, FORUM, AUTHOR
  foreach ($self->split_lines($response->content())) 
    {
    next if m/^\s*$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $START && 
        m=[-0-9]+\sof\s(?:about|exactly)\s(\d+)\smatches=)
      {
      # Actual lines of input:
      #         <font face=arial,helvetica size=-1>messages 1-100 of about 2500000 matches</font>
      # <b class="small">1-100 of exactly 3545 matches</b>
      print STDERR "count line \n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in START mode, and line has number of results

    elsif ($state eq $HITS &&
           m@<a\shref=\"([^\"]+)\">next\s(matches|messages)@i)
      {
      # Actual line of input is:
      # <b><font face="arial,helvetica" size=2><a href="http://x1.deja.com/dnquery.xp?search=next&DBS=1&LNG=ALL&IS=Martin%20Thurn&ST=PS&offsets=db98p4x%02100&svcclass=dnserver&CONTEXT=903630253.1503199236">Next matches</a></font>
      # <span class="small"><a href="http://x33.deja.com/dnquery.xp?search=next&LNG=ALL&IS=boba%20fett&ST=QS&offsets=db99p9%02100&CONTEXT=944504254.1945698352">next messages</a></span>
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      $self->{_next_url} = $1;
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $state = $ALLDONE;
      }

#      elsif ($state eq $HITS &&
#             m{>(\++)</font>})
#        {
#        print STDERR "hit score line\n" if 2 <= $self->{'_debug'};
#        # Actual line of input:
#        #         <b><font face="arial,helvetica" color="#ff6600">++++</font><font face="arial,helvetica" size=+1 color="#ffcc99">-</font></b><br>
#        if (ref($hit))
#          {
#          push(@{$self->{cache}}, $hit);
#          }
#        $hit = new WWW::SearchResult;
#        # Count the number of plus-signs and multiply by 20% for each one:
#        $hit->score(20 * length($1));
#        $state = $URL;
#        } #

    elsif ((($state eq $URL) || ($state eq $HITS)) && 
           m|<a\shref=\"?([^\">]+)\"?>([^<]+)?|i)
      {
      next if m/previous\s(matches|messages)/i;
      if (m/\076Power\ssearch\074/i)
        {
        $state = $ALLDONE;
        next;
        } # if
      next if (m/Track\sthis\ssearch/i);
      next if (m/sort_down_x\.gif/);
      if (m/linkback\.xp/)
        {
        $state = $ALLDONE;
        next;
        } # if
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual lines of input:
      # <td align=left><a href=http://x10.deja.com/getdoc.xp?AN=365996516&CONTEXT=899408575.427622419&hitnum=8><b>Stuffed Chewbacca</b></a><br>
      # <font face="geneva,arial" size=2 color="#999999">Previous matches</font></b>
      # For a more detailed search go to <a href="http://www.deja.com/home_ps.shtml?QRY=perlcom">Power Search</a></font></td>
      #     <a href="http://x44.deja.com/getdoc.xp?AN=546934725&CONTEXT=944500768.1493827592&hitnum=92">
      my $sURL = $1 . '&fmt=raw';
      if (ref($hit))
        {
        $hit->description($sDescription);
        push(@{$self->{cache}}, $hit);
        $sDescription = '';
        }
      $hit = new WWW::SearchResult;
      $hit->add_url($sURL);
      $hit->change_date($sDate) if $sDate ne '';
      $sDate = '';
      $self->{'_num_hits'}++;
      $hits_found++;
      $state = $TITLE;
      }
    elsif ($state eq $HITS && m!<td>(\d+/\d+/\d+)</td>!)
      {
      # Actual line of input is:
      #     <td>12/05/1999</td>
      print STDERR " date\n" if 2 <= $self->{'_debug'};
      $sDate = $1;
      $state = $URL;
      }

    elsif ($state eq $TITLE)
      {
      if (ref($hit))
        {
        my $sTitle = $_;
        chomp $sTitle;
        $sTitle =~ s/^\s+//;  # delete leading spaces
        $hit->title($sTitle);
        } # if
      $state = $FORUM;
      } # if TITLE

    elsif ($state eq $FORUM &&
           m|<td>([^<]+?)</td>|i)
      {
      print STDERR "forum line\n" if 2 <= $self->{'_debug'};
      # Actual line of input is:
      #     <td>rec.arts.sf.starwars.</td>
      my $sForum = $1;
      $sForum =~ s/\s+$//;  # delete trailing whitespace
      $sDescription .= "Newsgroup: $sForum";
      $state = $AUTHOR;
      }
    elsif ($state eq $AUTHOR && m|\">(.*?)</a>|i)
      {
      # Actual line of input is:
      #     <td><a href="profile.xp?author=315f0ddb1fd3416693f002e3662d9640ae3e4d3b2bceb4bf6eb0da6a80c070068f1069a1e792e4577e8fd9a49eb1d898171e5ed278071e92d5&ST=QS&ee=1">ceasar         </a></td>
      print STDERR "author\n" if 2 <= $self->{'_debug'};
      $sDescription .= "; Author: $1";
      $state = $HITS;
      } # line is end of description

    else
      {
      print STDERR "didn't match\n" if 2 <= $self->{'_debug'};
      }
    } # foreach line of query results HTML page

  if ($state ne $ALLDONE)
    {
    # End, no other pages (missed some tag somewhere along the line?)
    $self->{_next_url} = undef;
    }
  if (ref($hit)) 
    {
    $hit->description($sDescription);
    push(@{$self->{cache}}, $hit);
    }
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__

default hairy search URL:

http://www.dejanews.com/dnquery.xp?QRY=Chewbacca&ST=PS&DBS=1&defaultOp=OR&maxhits=10&format=verbose2&showsort=score

new URL 1998-08-20:

http://x1.dejanews.com/dnquery.xp?QRY=Martin+Thurn&ST=PS&defaultOp=OR&DBS=1&showsort=score&maxhits=100&LNG=ALL&format=delta

URL to get "text-only" of an article:

http://x10.dejanews.com/getdoc.xp?AN=365996516&CONTEXT=899408575.427622419&hitnum=8&fmt=raw

new basic search URL 1999-12-06:

http://www.deja.com/dnquery.xp?DBS=2&ST=MS&test=SA&QRY=Martin+Thurn&svcclass=dncurrent

new power search URL 1999-12-06:

http://www.deja.com/[ST_rn=ps]/qs.xp?ST=PS&svcclass=dnyr&QRY=boba+fett&defaultOp=OR&DBS=1&OP=dnquery.xp&LNG=ALL&subjects=&groups=&authors=&fromdate=&todate=&showsort=score&maxhits=100

simplest:

http://www.deja.com/qs.xp?QRY=boba+fett&defaultOp=OR&OP=dnquery.xp&LNG=ALL&showsort=score&maxhits=100
