##########################################################
# LookSmart.pm
# by Jim Smyser
# Copyright (C) 1996-1999 by Jim Smyser & USC/ISI
# $Id: LookSmart.pm,v 1.3 1999/07/14 17:10:30 mthurn Exp $
##########################################################


package WWW::Search::LookSmart;


=head1 NAME

WWW::Search::LookSmart - class for searching LookSmart 


=head1 SYNOPSIS

use WWW::Search;
my $Search = new WWW::Search('LookSmart'); # cAsE matters
my $Query = WWW::Search::escape_query("Where is Jimbo");
$Search->native_query($Query);
while (my $Result = $Search->next_result()) {
print $Result->url, "\n";
}

=head1 DESCRIPTION

This class is a LookSmart specialization of WWW::Search.
It handles making and interpreting LookSmart searches
F<http://looksmart.com>.

LookSmart will first display it's own internal site results
from it's many categories if found there, else it will 
return outside results from the web. Thus, depending on the
query there will be slightly two different formats returned
depending on whether or not LookSmart finds them in it's own
internal categories. All in all, this is a nice search engine! 

LookSmart only returns 10 hits per page and there is no search
options.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.


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
See $TEST_CASES below.

=head1 AUTHOR
This backend is maintained and supported by Jim Smyser.
<jsmyser@bigfoot.com>

C<WWW::Search::NorthernLight> was originally written by Andreas Borchert
based on C<WWW::Search::Excite>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=head1 VERSION HISTORY

2.01
New test mechanism

1.00
First release

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
&test('LookSmart', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('LookSmart', '$MAINTAINER', 'one', '+LSA'.'M +I'.'B +repl'.'ication', \$TEST_RANGE, 1,10);
&test('LookSmart', '$MAINTAINER', 'two', '+LS'.'AM +I'.'B', \$TEST_GREATER_THAN, 10);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search {
     my($self, $native_query, $native_options_ref) = @_;
     $self->{_debug} = $native_options_ref->{'search_debug'};
     $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
     $self->{_debug} = 0 if (!defined($self->{_debug}));
     $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
     $self->user_agent('user');
     $self->{_next_to_retrieve} = 1;
     $self->{'_num_hits'} = 0;
 
     if (!defined($self->{_options})) {
     $self->{'search_base_url'} = 'http://looksmart.com';
     $self->{_options} = {
         'search_url' => 'http://looksmart.com/r_search',
         'key' => $native_query,
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
     print STDERR "**LookSmart::native_retrieve_some()**\n" if $self->{_debug};
     return undef if (!defined($self->{_next_url}));
     # ZzzzzzzZZZzzzzzzzZZzz
     $self->user_agent_delay;
     print STDERR "**Sending request (",$self->{_next_url},")\n" if $self->{_debug};
     my($response) = $self->http_request('GET', $self->{_next_url});
     $self->{response} = $response;
       if (!$response->is_success) 
       {
       return undef;
       }
     $self->{'_next_url'} = undef;
     print STDERR "**Response\n" if $self->{_debug};
     # parse the output
     my ($HEADER, $HITS, $DESC, $DATE) = qw(HE HI DE DA);
     my $hits_found = 0;
     my $state = $HEADER;
	 my($raw);
     my $hit = ();
     foreach ($self->split_lines($response->content()))
     {
     next if m@^$@; # short circuit for blank lines
     print STDERR " $state ===$_=== " if 2 <= $self->{'_debug'};
     if (m|(\d+)-(\d+)\s+matches|i) {
     print STDERR "Total Pages Returned\n" if ($self->{_debug});
     $state = $HITS;
 } elsif (m|(\d+)-(\d+)\s+site\s+matches|i) {
     print STDERR "Total Pages Returned\n" if ($self->{_debug});
     $state = $HITS;
 } elsif ($state eq $HITS && m@<a[^>]*href="\http://([^"]+)\"[^>]*>(.*)</a>@i) {
     print STDERR "**Found Hit URL**\n" if 2 <= $self->{_debug};
     my ($url, $title) = ($1,$2);
     if (defined($hit)) 
     {
     push(@{$self->{cache}}, $hit);
     };
     $hit = new WWW::SearchResult;
     $raw .= $_;
     $url = 'http://'. $url if (not $url =~ m@^http://@);
     $hit->add_url($url);
     $hits_found++;
     $hit->title($title);
     $state = $DESC;
 } elsif ($state eq $DESC && m@^(.+)<br>@i) {
     print  "**Found Description**\n" if 2 <= $self->{_debug};
     $raw .= $_;
     $hit->description($1);
     $state = $DATE;
 } elsif ($state eq $DATE && m@<font color=.*?>(.*)</font><br>@i) {
     print  "**Found Date - This is an External Hit**\n" if 2 <= $self->{_debug};
     $raw .= $_;
     $hit->index_date($1);
     $state = $HITS;
 } elsif ($state eq $DATE && m@<a href="/r(.*?)">(.*)</a>@i) {
     print  "**Internal LookSmart Site Hit**\n" if 2 <= $self->{_debug};
     # I suppose one could use related_urls, _titles if desired here
     $state = $HITS;
 } elsif ($state eq $HITS && m@.*?<a href="([^"]+)">Next&nbsp;(\d+)</a>@i) {
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
        $hit->raw($raw);
        push(@{$self->{cache}}, $hit);
        } 
        return $hits_found;
     } # native_retrieve_some
1;
