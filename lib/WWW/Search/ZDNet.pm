#!/usr/local/bin/perl -w
         
#
# ZDnet.pm
# by Jim Smyser
# Copyright (C) 1996-1998 by USC/ISI
# $Id: ZDNet.pm,v 1.1 1999/05/27 23:15:58 johnh Exp $
# Complete copyright notice follows below.
#
         
         
package WWW::Search::ZDNet;
         
=head1 NAME
         
WWW::Search::ZDnet - class for searching ALL of ZDnet

        
=head1 SYNOPSIS
         
require WWW::Search;
$search = new WWW::Search('ZDnet');
         
         
=head1 DESCRIPTION


Class for searching ALL of ZDnet.
F<http://xlink.zdnet.com>.

ZDNet is no longer returning 'descriptions' :(

Searches articles in: Anchordesk, Community, Computer Life,
Computer Shopper, NetBuyer, DevHead, Family PC, Help Channel,
Inter@ctive Week, Internet, MacWEEK, PC Computing, PC Magazine
CD, PC Week, Products, Sm@rt Reseller, Software, Library, Yahoo
Internet Life, ZDNN, ZDTV.

Note that dupe articles can appear because they are published in
more than one category on ZDnet, or same Title published on
different dates.


Print options:

Using $result->{'index_date'} will return categore and date enclosed 
in brackets, example: [PC Week, 12-14-98].
This makes for  anice trailer after the description if desired. 

Raw, of course, returns all the HTML of each hit.

This class exports no public interface; all interaction should
be done through WWW::Search objects.
         
         
=head1 SEE ALSO
         
To make new back-ends, see L<WWW::Search>.
         
         
=head1 HOW DOES IT WORK?
         
C<native_setup_search> is called before we do anything.
It initializes our private variables (which all begin with underscores)
and sets up a URL to the first results page in C<{_next_url}>.
         
C<native_retrieve_some> is called (from C<WWW::Search::retrieve_some>)
whenever more hits are needed.  It calls the LWP library
to fetch the page specified by C<{_next_url}>.
It parses this page, appending any search hits it finds to
C<{cache}>.  If it finds a ``next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we're done.
         
         
=head1 AUTHOR
         
Maintained by Jim Smyser <jsmyser@bigfoot.com>
         
=head1 TESTING


    $search_engine = 'ZDnet';
    $maintainer = 'Jim Smyser <jsmyser@bigfoot.com>';

    $file = 'test/ZDnet/zero_result'; 
    $query = $bogus_query; 
    test($mode, $TEST_EXACTLY); 
      
    $file = 'test/ZDnet/one_page_result'; 
    $query = 'Me' . 'ta+Search+Perl';
    test($mode, $TEST_RANGE, 2, 25);

    $file = 'test/ZDnet/multi_page_result'; 
    $query = 'as' . 'tronomy';
    test($mode, $TEST_GREATER_THAN, 49); 



=head1 COPYRIGHT
         
The original parts from John Heidemann are subject to
following copyright notice:
         
Copyright (c) 1996-1998 University of Southern California.
All rights reserved.
                                                                        
Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation, advertising
materials, and other materials related to such distribution and use
acknowledge that the software was developed by the University of
Southern California, Information Sciences Institute.  The name of the
University may not be used to endorse or promote products derived from
this software without specific prior written permission.
         
THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
         
=cut
#'
         
         
#####################################################################
         
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.02';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;
# Martin's version scheme.
sub version {$VERSION}


sub native_setup_search
{
    my($self, $native_query, $native_options_ref) = @_;
    $self->{_debug} = $native_options_ref->{'search_debug'};
    $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
    $self->{_debug} = 0 if (!defined($self->{_debug}));
    $self->{'_hits_per_page'} = '100';
    $self->{agent_e_mail} = 'jsmyser@bigfoot.com.com';
    $self->user_agent('non-robot');
    $self->{_next_to_retrieve} = 1;
    $self->{'_num_hits'} = 0;
         if (!defined($self->{_options}))
            {
           $self->{'search_base_url'} = 'http://xlink.zdnet.com';
           $self->{_options} = {
          '&frame' => '&Utype=D&Uch=all&Utqt=and&Unbr=100&Urt=D&Uat=AllTypes&Udat=all',
          'Utext' => $native_query,
           'search_url' => 'http://xlink.zdnet.com/cgi-bin/texis/xlink/more/search.html',
      };
        } 
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
    foreach (sort keys %$options_ref)
      {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
      }
    chop $options;
    # Finally figure out the url.
    $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      } # native_setup_search
# New Hit Stuff....
sub begin_new_hit
      {
    my($self) = shift;
    my($old_hit) = shift;
    my($old_raw) = shift;
    # Save it....
 if (defined($old_hit)) {
    $old_hit->raw($old_raw) if (defined($old_raw));
    push(@{$self->{cache}}, $old_hit);
      };
    # Make a new hit.
    return (new WWW::SearchResult, '');
      }
# private
sub native_retrieve_some
     {
    my ($self) = @_;
    print STDERR " **ZDnet::native_retrieve_some()\n" if $self->{_debug};
    # Fast exit if already done....
    return undef if (!defined($self->{_next_url}));
    # Sleep to not overload server.....
    $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
      
    # Get some....
    print STDERR "** sending request (",$self->{_next_url},")\n" if $self->{_debug};
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
 if (!$response->is_success)
      {
    return undef;
      }
    $self->{'_next_url'} = undef;
    print STDERR "***got response\n" if $self->{_debug};
    # parse the output
    my ($HEADER, $HITS, $DESC) = qw(HE HI DE);
    my $hits_found = 0;
    my $state = $HEADER;
    my ($raw) = '';
    my $hit = ();
    foreach ($self->split_lines($response->content()))
       {
    next if m@^$@; # short circuit for blank lines
    print STDERR "** $state ===$_=== " if 2 <= $self->{'_debug'};
 if (m@<td valign=top bgcolor=FFFFFF colspan=3>@i) {
    $state = $HITS;
      }   
 if ($state eq $HITS && m@<a href="(.*?)">(.*)</A></FONT>@i) {
    print STDERR "**URL hit line\n" if 2 <= $self->{_debug};
    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
    $raw .= $_;
    $hit->add_url($1);
    $hits_found++;
    $hit->title($2);
 $state = $HITS;
    # return anything undesirable....
} elsif ($state eq $HITS && m{(<b>(.*)</b>)}i) {
    $raw .= $_;
    $hit->index_date($1);

} elsif ($state eq $HITS && m|<A HREF=(.*)>(\d+)\s-\s(\d+)|i) {
    print STDERR "**Sending 'next' page URL\n" if 2 <= $self->{_debug};
    my $sURL = $1;
    $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
    $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/first=(\d+)/;
    $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
    print STDERR "** Next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
    $state = $HITS;
       } else {
    print STDERR "**Nothing matched\n" if 2 <= $self->{_debug};
     }
       } # foreach
  return $hits_found;
    } # native_retrieve_some
1;
__END__
<TR><TD>&#149;</TD><TD><FONT FACE="HELVETICA, ARIAL, SANS-SERIF" SIZE="2">
<A HREF="http://xlink.zdnet.com/cgi-bin/texis/xlink/redirector/main.bin?DHq=cobol&amp;DHuid=206.80.202.154&amp;DHrank=77&amp;DHtotal=100&amp;DHtime=Sat+Mar+27+19%3A45%3A28+GMT+1999&amp;DHu=http://www.zdnet.com/pcmag/insites/miller_print/mm980911.htm" target="_top">PC Magazine: Y2K: Reality and Myth (9/11/98)</A></FONT>
<font face="HELVETICA, ARIAL, SANS-SERIF" size=1>
<b>[PC Magazine, 09-11-98]</b>
</font>
</TD></TR>
