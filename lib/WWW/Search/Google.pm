##########################################################
# Google.pm
# by Jim Smyser
# Copyright (C) 1996-1999 by Jim Smyser & USC/ISI
# $Id: Google.pm,v 1.8 1999/09/30 13:03:45 mthurn Exp $
##########################################################


package WWW::Search::Google;


=head1 NAME

WWW::Search::Google - class for searching Google 


=head1 SYNOPSIS

use WWW::Search;
my $Search = new WWW::Search('Google'); # cAsE matters
my $Query = WWW::Search::escape_query("Where is Jimbo");
$Search->native_query($Query);
while (my $Result = $Search->next_result()) {
print $Result->url, "\n";
}

=head1 DESCRIPTION

This class is a Google specialization of WWW::Search.
It handles making and interpreting Google searches.
F<http://www.google.com>.

Googles returns 100 Hits per page. Custom Linux Only search capable.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 LINUX SEARCH

For LINUX lovers like me, you can put Googles in a LINUX only search
mode by changing search URL from:

 'search_url' => 'http://www.google.com/search',

to:

 'search_url' => 'http://www.google.com/linux',

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


=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

=head1 AUTHOR

This backend is maintained and supported by Jim Smyser.
<jsmyser@bigfoot.com>

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 BUGS

Since this is a new Backend there are undoubtly one. Report any ASAP. 

=head1 VERSION HISTORY

2.05
Matching overhaul to get the code parsing right due to multiple 
tags being used by google on the hit lines. 9/25/99

2.02
Last Minute description changes  7/13/99

2.01
New test mechanism  7/13/99

1.00
First release  7/11/99

=cut
#'

#####################################################################
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '2.05';

$MAINTAINER = 'Jim Smyser <jsmyser@bigfoot.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Google', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Google', '$MAINTAINER', 'one_page', '+LS'.'AM +rep'.'lication', \$TEST_RANGE, 2,49);
&test('Google', '$MAINTAINER', 'multi', 'dir'.'ty ha'.'rr'.'y bimbo', \$TEST_GREATER_THAN, 101);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search {

     my ($self, $native_query, $native_options_ref) = @_;
     $self->{_debug} = $native_options_ref->{'search_debug'};
     $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
     $self->{_debug} = 0 if (!defined($self->{_debug}));
     my $DEFAULT_HITS_PER_PAGE = 100;
     $DEFAULT_HITS_PER_PAGE = 20 if 0 < $self->{_debug};
     $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;
     $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
     $self->user_agent('user');
     $self->{_next_to_retrieve} = 1;
     $self->{'_num_hits'} = 0;
     if (!defined($self->{_options})) {
     $self->{'search_base_url'} = 'http://www.google.com';
     $self->{_options} = {
        # uncomment the next line for Linux searchs
        # 'search_url' => 'http://www.google.com/linux',
         'search_url' => 'http://www.google.com/search',
         'q' => $native_query,
         'num' => $self->{'_hits_per_page'},
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
     print STDERR "**Google::native_retrieve_some()**\n" if $self->{_debug};
     return undef if (!defined($self->{_next_url}));
     # ZzzzzzzZZZzzzzzzzZZzz
     $self->user_agent_delay;
     print STDERR "**Sending request (",$self->{_next_url},")\n" if $self->{_debug};    
     my($response) = $self->http_request('GET', $self->{_next_url});      
     $self->{response} = $response;        
     if (!$response->is_success) {
       return undef;
       }
     $self->{'_next_url'} = undef;
     print STDERR "**Parse the Results**\n" if $self->{_debug};

     # parse the output
     my ($HEADER, $HITS)  = qw(HE HI);
     my $hits_found = 0;
     my $hit = ();
     foreach ($self->split_lines($response->content()))
     {
     next if m@^$@; # short circuit for blank lines
     print STDERR " $state ===$_=== " if 2 <= $self->{'_debug'};
     if (m|<html>|i) {
     print STDERR "**Header Found**\n" if ($self->{_debug});
     $self->approximate_result_count($1);
     $state = $HITS;

 } if ($state eq $HITS && m@<p><a href=([^<]+)>(.*)</a>@i) {
     print "**Found Hit URL**\n" if 2 <= $self->{_debug};
     my ($url, $title) = ($1,$2);
     if (defined($hit)) 
     {
     push(@{$self->{cache}}, $hit);
     };
     $hit = new WWW::SearchResult;
     $hits_found++;
     $hit->add_url($url);
     $hit->title($title);
     $state = $HITS;

     # There is either a </UL> or <UL> tag
 } elsif ($state eq $HITS && m@<.?UL><a href=([^<]+)>(.*)</a>@i) {
     print "**Found Hit URL**\n" if 2 <= $self->{_debug};
     my ($url, $title) = ($1,$2);
     if (defined($hit)) 
     {
     push(@{$self->{cache}}, $hit);
     };
     $hit = new WWW::SearchResult;
     $hits_found++;
     $hit->add_url($url);
     $hit->title($title);
     $state = $HITS;

 } elsif ($state eq $HITS && m@<font size=-1><br>(.*)<br>@i) {
      print "**Found Description**\n" if 2 <= $self->{_debug};
      $mDesc .= $1;
      $mDesc =  $mDesc . '<br>'; 

 } elsif ($state eq $HITS && m@^(\.(.+))@i) {
      print "**Found Next Description**\n" if 2 <= $self->{_debug};
      $mDesc .= $1;
      $hit->description($mDesc) if (defined($hit)); 
      $mDesc = '';
      $state = $HITS;

 } elsif ($state eq $HITS && m|<a href=([^<]+)><IMG SRC=/nav_next.gif.*?><br><.*?>Next page</A>|i) {
     print STDERR "**Going to Next Page**\n" if 2 <= $self->{_debug};
     my $URL = $1;
     $self->{'_next_to_retrieve'} = $1; 
     $self->{'_next_url'} = $self->{'search_base_url'} . $URL;
     print STDERR "**Next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
     $state = $HITS;
     } else {
     print STDERR "**Nothing Matched.**\n" if 2 <= $self->{_debug};
     }
     } 
     if (defined($hit)) {
        push(@{$self->{cache}}, $hit);
        } 
        return $hits_found;
     } # native_retrieve_some
1;




