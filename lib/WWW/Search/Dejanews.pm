# Dejanews.pm
# Copyright (C) 1998 by Martin Thurn
# $Id: Dejanews.pm,v 1.6 1998/12/03 14:41:05 mthurn Exp $

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
F<http://www.dejanews.com>.

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

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

Test cases:

    $file = 'test/Dejanews/zero_result';
    $query = 'Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Dejanews/one_page_result';
    $query = 'Fe'.'tt AND st'.'untboy;
    test($mode, $TEST_RANGE, 2, 50);

    $file = 'test/Dejanews/multi_page_result';
    $query = 'Chewb'.'acca';
    test($mode, $TEST_GREATER_THAN, 101);

=head1 AUTHOR

C<WWW::Search::Dejanews> is maintained by Martin Thurn
(MartinThurn@iname.com); 
original version for WWW::Search by Cesare Feroldi de Rosa (C.Feroldi@it.net).

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

=head2 1.11, 1998-12-03

Now uses the split_lines() function;
sync with WWW::Search distribution's version number

=head2 1.4, 1998-08-27

New Dejanews output format

=head2 1.3, 1998-08-20

New Dejanews output format

=head2 1.2

First publicly-released version.

=cut

#####################################################################

package WWW::Search::Dejanews;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.11';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


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
                         'search_url' => 'http://www.Dejanews.com/dnquery.xp',
                         'QRY' => $native_query,
                         'ST' => 'PS',
                         'defaultOp' => 'OR',
                         'maxhits' => $self->{'_hits_per_page'},
                         'format' => 'delta',
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

  # Build the options part of the URL:
  my $options = '';
  foreach (keys %{$self->{'_options'}})
    {
    # printf STDERR "option: $_ is " . $self->{'_options'}->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $self->{'_options'}->{$_} . '&';
    }

  # Finally, figure out the url.
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
  my $response = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    };

  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($START, $HEADER, $HITS, $URL,$DATE,$FORUM, $TRAILER, $ALLDONE) = qw(ST HE HI UR DA FO TR AD);
  my $hits_found = 0;
  my $state = $START;
  my ($hit, $sDescription);
  foreach ($self->split_lines($response->content())) 
    {
    next if m/^\s*$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $START && 
        m=messages\s[-0-9]+\sof\s(about|exactly)\s(\d+)\smatches=)
      {
      # Actual line of input is:
      #         <font face=arial,helvetica size=-1>messages 1-100 of about 2500000 matches</font>
      print STDERR "count line \n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($2);
      $state = $HITS;
      } # we're in START mode, and line has number of results

    elsif ($state eq $HITS &&
           m@<a\shref=\"([^\"]+)\">Next\smatches@)
      {
      # Actual line of input is:
      # <b><font face="arial,helvetica" size=2><a href="http://x1.dejanews.com/dnquery.xp?search=next&DBS=1&LNG=ALL&IS=Martin%20Thurn&ST=PS&offsets=db98p4x%02100&svcclass=dnserver&CONTEXT=903630253.1503199236">Next matches</a></font>
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
#        if (defined($hit))
#          {
#          push(@{$self->{cache}}, $hit);
#          }
#        $hit = new WWW::SearchResult;
#        # Count the number of plus-signs and multiply by 20% for each one:
#        $hit->score(20 * length($1));
#        $state = $URL;
#        } #

    elsif ((($state eq $URL) || ($state eq $HITS)) && 
           m|<a\shref=\"?([^\">]+)\"?>([^<]+)|i)
      {
      next if m/Previous\smatches/;
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <td align=left><a href=http://x10.dejanews.com/getdoc.xp?AN=365996516&CONTEXT=899408575.427622419&hitnum=8><b>Stuffed Chewbacca</b></a><br>
      my $sURL = $1 . '&fmt=raw';
      my $sTitle = $2;
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $hit->add_url($sURL);
      $self->{'_num_hits'}++;
      $hits_found++;
      $hit->title($sTitle);
      $sDescription = '';
      $state = $FORUM;
      }

    elsif ($state eq $FORUM &&
           m|Forum</b>:\s([^<]+)|i)
      {
      print STDERR "forum line\n" if 2 <= $self->{'_debug'};
      # Actual line of input is:
      # 	<b>Forum</b>: rec.birds<br>
      $sDescription .= "Newsgroup: $1";
      $state = $DATE;
      }
    elsif ($state eq $DATE &&
           m|Date</b>:\s([^\s]+).*?Author</b>: (.*)|i)
      {
      # Actual line of input is:
      # 	<b>Date</b>: 1998/08/20 <b>Author</b>: James Hanst
      $hit->change_date($1);
      $sDescription .= "; Author: $2";
      $hit->description($sDescription);
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
  if (defined($hit)) 
    {
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
