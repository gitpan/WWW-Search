#!/usr/local/bin/perl -w
 
###########################################################
# ZDnet.pm
# by Jim Smyser
# Copyright (C) 1999 by Jim Smyser & USC/ISI
# $Id: ZDNet.pm,v 1.5 1999/11/30 14:16:54 mthurn Exp $
###########################################################
 
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

Using $result->{'source'} will return category and date enclosed 
in brackets, example: [PC Week, 12-14-98]. use this in place of
description since there is NO descriptions anymore with ZDNet.

Raw, of course, returns all the HTML of each hit.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 AUTHOR

Maintained by Jim Smyser <jsmyser@bigfoot.com>

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 
See $TEST_CASES below.

=head1 VERSION HISTORY

=head2 2.01, 1999-07-13

Fixed pod syntax;
new test mechanism

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
 
#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '2.02';

$MAINTAINER = 'Jim Smyser <jsmyser@bigfoot.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('ZDNet', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('ZDNet', '$MAINTAINER', 'one', 'Meta Search Perl', \$TEST_RANGE, 2,84);
&test('ZDNet', '$MAINTAINER', 'two', 'astronomy', \$TEST_GREATER_THAN, 87);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

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
    print STDERR " **ZDnet::native_retrieve_some()**\n" if $self->{_debug};
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
    my ($HEADER, $HITS, $DATE) = qw(HE HI DA);
    my $hits_found = 0;
    my $state = $HEADER;
    my ($raw) = '';
    my $hit = ();
    foreach ($self->split_lines($response->content()))
       {
    next if m@^$@; # short circuit for blank lines
    print STDERR "** $state ===$_=== **" if 2 <= $self->{'_debug'};
 if (m@<TITLE>.*?</TITLE>@i) {
   $state = $HITS;
    }   
 elsif ($state eq $HITS && m@<A HREF=.*?DHu=(.*)\"\starget="_top">(.*)</A></FONT>@i) {
    print STDERR "**Found URL**\n" if 2 <= $self->{_debug};
    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
    $raw .= $_;
    $hit->add_url($1);
    $hits_found++;
    $hit->title($2);
    $state = $DATE;

} elsif ($state eq $DATE && m@^<b>(.*)</b>@) {
    print STDERR "**Found DATE**\n" if 2 <= $self->{_debug};
    $raw .= $_;
    $hit->source($1);
    $state = $HITS;
} elsif ($state eq $HITS && m@<A HREF="http://www.thunderstone.com">@i) {
    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
    print STDERR "**No More Hits**\n" if 2 <= $self->{_debug};
    #End of Hits
} elsif ($state eq $HITS && m|<A HREF=(.*)>(\d+)\s-\s(\d+)|i) {
    print STDERR "**Going to Next Page**\n" if 2 <= $self->{_debug};
       my $sURL = $1;
       $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/first=(\d+)/;
       $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
    print STDERR "** Next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
    $state = $HITS;
       } else {
    print STDERR "**Nothing Matched**\n" if 2 <= $self->{_debug};
     }
       } # foreach
  return $hits_found;
    } # native_retrieve_some
1;

