# Snap.pm
# by Jim Smyser
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Snap.pm,v 1.3 1999/07/13 17:45:09 mthurn Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::Snap;

=head1 NAME

WWW::Search::Snap - class for searching Snap.com! 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Snap');

=head1 DESCRIPTION

Class specialization of WWW::Search for searching F<http://snap.com>.
Snap.com can return up to 1000 hits.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 OPTIONS

Some options for modifying a search

=item   {'KM' => 'a'}
All the words

=item   {'KM' => 'b'}
Boolean Search

=item   {'KM' => 'o'}
Any of the words

=item   {'KM' => 't'}
Searches Title only

=item   {'KM' => 's'}
All forms of the words

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>,
or the specialized AltaVista searches described in options.

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

C<WWW::Search::Snap> is written and maintained
by Jim Smyser - <jsmyser@bigfoot.com>.

=head1 TESTING

This backend adheres to the C<WWW::Search> test mechanism.
See $TEST_CASES below.      

=head1 COPYRIGHT

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
$VERSION = '2.01';

$MAINTAINER = 'Jim Smyser <jsmyser@bigfoot.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Snap', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Snap', '$MAINTAINER', 'one', 'vbt'.'hread', \$TEST_RANGE, 2,99);
&test('Snap', '$MAINTAINER', 'two', 'Bos'.'sk', \$TEST_GREATER_THAN, 101);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search {
   my($self, $native_query, $native_options_ref) = @_;
   $self->{_debug} = $native_options_ref->{'search_debug'};
   $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
   $self->{_debug} = 0 if (!defined($self->{_debug}));
   #Define default number of hit per page
   $self->{'_hits_per_page'} = 100;
   $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
   $self->user_agent('user');
   $self->{_next_to_retrieve} = 1;
   $self->{'_num_hits'} = 0;
   $self->timeout(60);
# Hack of mine to force AND between words in Boolean mode
#   $native_query =~ s/(\w)\053/$1\053\AND\053/g;
   if (!defined($self->{_options})) {
     $self->{'search_base_url'} = 'http://home.snap.com';
     $self->{_options} = {
         'search_url' => 'http://home.snap.com/search/power/results/1,180,home-0,00.html',
           'KM' => 'a', 
           'KW' => $native_query,
           'AM0' => 'm',
           'AT0' => 'w',
           'AN' => '1',
           'NR' => $self->{'_hits_per_page'},
           'FR' => 'f',
           'PL' => 'a',
           'DR' => '0',
           'FM' => '1',
           'FD' => '1',
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

# private
sub native_retrieve_some
    {
    my ($self) = @_;
    print STDERR "**Snap::native_retrieve_some()\n" if $self->{_debug};
    
    # Fast exit if already done:
    return undef if (!defined($self->{_next_url}));
    
    # If this is not the first page of results, sleep so as to not
    # overload the server:
    $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
    
    # Get some:
    print STDERR "**Requesting (",$self->{_next_url},")\n" if $self->{_debug};
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) 
      {
      return undef;
      }
    $self->{'_next_url'} = undef;
    print STDERR "**Found Some\n" if $self->{_debug};
    # parse the output
    my ($HEADER, $HITS, $DESC) = qw(HE HI DE);
    my $state = $HEADER;
    my $hit = ();
    my $hits_found = 0;
    foreach ($self->split_lines($response->content()))
      {
     next if m@^$@; # short circuit for blank lines
     print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};
     if (m|Results:\s(\d+)|i) {
       $self->approximate_result_count($1);
       print STDERR "**Approx. Count\n" if ($self->{_debug});
       $state = $HITS;
       # Make sure we catch redirects Snap likes to randomly insert 
       # and filter them.....
  } if ($state eq $HITS && m@<b><a href="http://redirect.*?u=([^"]+)\&q=.*?>(.*)</a></b><br>@i) {
       print STDERR "**Found a URL\n" if 2 <= $self->{_debug};
       if (defined($hit)) 
         {
        push(@{$self->{cache}}, $hit);
         };
       $hit = new WWW::SearchResult;
       $hit->add_url($1);
       $hits_found++;
       $hit->title($2);
       $state = $DESC;

  } elsif ($state eq $HITS && m@<b><a href="([^"]+)">(.*)</a></b><br>@i) {
       print STDERR "**Found a URL\n" if 2 <= $self->{_debug};
       if (defined($hit)) 
         {
        push(@{$self->{cache}}, $hit);
         };
       $hit = new WWW::SearchResult;
       $hit->add_url($1);
       $hits_found++;
       $hit->title($2);
       $state = $DESC;
   } elsif ($state eq $DESC && m{(\w(.*)<br>)}i) {
       print STDERR "**Found description\n" if 2 <= $self->{_debug};
       $hit->description($1);
       $state = $HITS;
   } elsif ($state eq $HITS && m|<A HREF="([^"]+)">Next</A>|i) {
       print STDERR "**Found 'next' Tag\n" if 2 <= $self->{_debug};
       my $sURL = $1;
       $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/first=(\d+)/;
       $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
       print STDERR " **Next Tag is: ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
       $state = $HITS;
       } 
     else 
       {
       print STDERR "**Nothing Matched\n" if 2 <= $self->{_debug};
       }
  } if (defined($hit)) {
     push(@{$self->{cache}}, $hit);
     } 
   return $hits_found;
   } # native_retrieve_some
1;

