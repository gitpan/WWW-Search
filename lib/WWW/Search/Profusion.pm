#!/usr/local/bin/perl -w

#
# Profusion.pm
# by Jim Smyser
# Copyright (c) 1999 by Jim Smyser & USC/ISI
# $Id: Profusion.pm,v 1.1 1999/05/27 23:15:57 johnh Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::Profusion;

=head1 NAME

WWW::Search::Profusion - class for searching Profusion.com! 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Profusion');

=head1 DESCRIPTION

This class uses the Meta Search Engine F<http://www.profusion.com>.
Search engines searched are: 1) AltaVista 2) InfoSeek 3) Snap 4)
Excite 5) Lycos 6) WebCrawler 7) Magellan 8) Yahoo 9) GoTo

Most of the above defaults to Boolean. Profusion returns all retrieved
hits to one page, so, there is no next page retrievals.  

This class exports no public interface; all interaction should
be done through WWW::Search objects.

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

C<WWW::Search::Profusion> is written and maintained
by Jim Smyser - <jsmyser@bigfoot.com>.

=head1 TESTING
**This backend returns ALL results to *one* page.**

    $search_engine = 'Profusion';
    $maintainer = 'Jim Smyser <jsmyser@bigfoot.com>';

    $file = 'test/Profusion/zero_result'; 
    $query = $bogus_query; 
    test($mode, $TEST_EXACTLY); 
     
    $file = 'test/Profusion/one_page_result'; 
    $query = 'Astr' . 'onomy'; 
    test($mode, $TEST_GREATER_THAN, 50); 
      
  
=head1 COPYRIGHT

Copyright (c) 1996-1999 University of Southern California.
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

=head1 VERSION HISTORY

1.04 Fix for format change. Added striping of <b> tags in title so 
description does not get bolded over.

1.03 fixes minor parsing error where some hits were being ignored.
Also added returning of all HTML (raw).


=cut
#'

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
$VERSION = 1.04;
@ISA = qw(WWW::Search Exporter);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;



# private
sub native_setup_search
{
    my($self, $native_query, $native_options_ref) = @_;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 0;
    if (!defined($self->{_options})) {
 $self->{_options} = {
       'search_url' => 'http://www.profusion.com/cgi-bin/nph-ProFusion.pl',
       'current' => '0&display=0&auto=all&option=all&search=web&summary=Yes&totalverify=0&pid=&log=no',
        };
    };
    my($options_ref) = $self->{_options};
    if (defined($native_options_ref)) {
 # Copy in new options.
 foreach (keys %$native_options_ref) {
     $options_ref->{$_} = $native_options_ref->{$_};
 };
    };
    # Process the options.
    my($options) = '';
    foreach (keys %$options_ref) {
 # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
 next if (generic_option($_));
 $options .= $_ . '=' . $options_ref->{$_} . '&';
    };
    $self->{_debug} = $options_ref->{'search_debug'};
    $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
    $self->{_debug} = 0 if (!defined($self->{_debug}));
    # Finally figure out the url.
    $self->{_base_url} = 
 $self->{_next_url} =
 $self->{_options}{'search_url'} .
 "?" . $options .
 "queryterm=" . $native_query;
    print $self->{_base_url} . "\n" if ($self->{_debug});
}


# private
sub native_retrieve_some
{
    my ($self) = @_;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    print STDERR "**Fetching some....\n" if 2 <= $self->{_debug};
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
 return undef;
    };
    # parse the output
    my($HEADER, $HITS, $DESC) = (1..10);
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit, $raw, $title, $url, $rating, $desc) = ();
   
   foreach ($self->split_lines($response->content())) {
        next if m@^$@; # short circuit for blank lines
 print STDERR $ST[$state], ": " if ($self->{_debug} >= 2);
 if ($state == $HEADER && m@<hr>Ranking\sTitle@i) { 
        print STDERR "PARSE(HEADER->HITS-1): $_\n" if ($self->{_debug} >= 2);
     $state = $HITS;

 } elsif ($state == $HITS && m@.*?</b><a href="/cgi-bin/process_result.pl.?url==([^"]+)\&engine.*?>(.*)</b></font></a>.*?</i></font><br>(.*)</dl>@i) { 
        print STDERR "**Parsing URL & Title...\n" if 2 <= $self->{_debug};
        my ($url, $title, $description) = ($1,$2,$3);
     my($hit) = new WWW::SearchResult;
  $title =~ s/<b>//g;
     $hit->add_url($url);
     $hit->title($title);
     $hit->description($description);
     $hit->raw($_);
     $hits_found++;
     push(@{$self->{cache}}, $hit);
     $state = $HITS;
#  Profusion does now provide 'next' page url's if defined,
#  however I am going to ignore them for time being till
#  it looks like they will remain unchanged.
    print STDERR "**Parsing Hit...\n" if 2 <= $self->{_debug};
    };
 if (defined($hit)) {
     push(@{$self->{cache}}, $hit);
 };
 $self->{_next_url} = undef;
    };
    return $hits_found;
}
1;


