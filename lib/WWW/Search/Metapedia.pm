#!/usr/local/bin/perl -w

#
# Metapedia.pm
# by Jim Smyser
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Metapedia.pm,v 1.1 1999/06/18 19:15:36 mthurn Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Metapedia;

=head1 NAME

WWW::Search::Metapedia - class for searching online Encyclopedias 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Metapedia');


=head1 DESCRIPTION

Silly class I made to sponge off a Encyclopedia meta search engine. 
Searches multi online Encyclopedias.
Built off the old lycos.pm so to have 'RAW' output ability.
 
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


=head1 BUGS

Looks OK to me.

=head1 AUTHOR
Jim Smyser <jsmyser@bigfoot.com>

based upon C<WWW::Search::Lycos>.

=head1 TESTING

This module adheres to the C<WWW::Search> test routines. 

    $search_engine = 'Metapedia';
    $maintainer = 'Jim Smyser <jsmyser@bigfoot.com>';

    $file = 'test/Metapedia/zero_result'; 
    $query = $bogus_query; 
    test($mode, $TEST_EXACTLY); 
     
    $file = 'test/Metapedia/one_page_result'; 
    $query = 'hydro' . 'celphy'; 
    test($mode, $TEST_RANGE, 2, 15); 
      
    $file = 'test/Metapedia/multi_page_result'; 
    $query = 'Ast' . 'ronomy';
    test($mode, $TEST_GREATER_THAN, 30); 


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

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;



# private
sub native_setup_search {
    my($self, $native_query, $native_options_ref) = @_;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 0;
    if (!defined($self->{_options})) {
	$self->{_options} = {
	    'cat' => '63',
	    'search_url' => 'http://www.savvysearch.com/search',
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
	"q=" . $native_query;
    print $self->{_base_url} . "\n" if ($self->{_debug});
}
# private
sub native_retrieve_some {
    my ($self) = @_;
    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    print STDERR "WWW::Search::Metapedia::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    my($HEADER, $HITS, $DESC, $TRAILER, $POST_NEXT) = (1..10);
    my(@ST) = ("", "HD", "HI", "DE", "TR", "PN"); 
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit, $raw, $title, $url, $desc) = ();
    foreach ($self->split_lines($response->content())) {
        next if m@^$@; # short circuit for blank lines
	print STDERR $ST[$state], ": " if ($self->{_debug} >= 2);
	if ($state == $HEADER && m@metasearch results (\d+) thru (\d+) of (\d+)@i) { 
	    $self->approximate_result_count($1);
            print STDERR "PARSE(HEADER->HITS-1): $_\n" if ($self->{_debug} >= 2);
	    $state = $HITS;

   } elsif ($state == $HITS && m@<dt><a href="([^"]+)">(.*)</font>@i) { 
	    print STDERR "PARSE(HITS->HITS): $_\n" if ($self->{_debug} >= 2);
	    my($hit) = new WWW::SearchResult;
	    $hit->add_url($1);
	    $hit->title($2);
	    $hit->description($3);
	    $hit->raw($_);
	    $hits_found++;
	    push(@{$self->{cache}}, $hit);
	} elsif ($state == $HITS && m@^<dt><a href="([^"]+)">(.*)\<\/a\>@i) { 
	    $raw = $_;
	    $url = $1;
	    $title = $2;
	    print STDERR "PARSE(HITS->DESC): $_\n" if ($self->{_debug} >= 2);
	    $state = $DESC;
	} elsif ($state == $DESC) {
	    $raw .= $_;
	    m@<dd>(.*)<br>@;
	    $desc = $2;
	    print STDERR "PARSE(DESC->HITS): $_\n" if ($self->{_debug} >= 2);
	    #
	    my($hit) = new WWW::SearchResult;
	    $hit->add_url($url);
	    $hit->title($title);
	    $hit->description($desc);
	    $hit->score($rating);
	    $hit->raw($raw);
	    $hits_found++;
	    push(@{$self->{cache}}, $hit);
	    $state = $HITS;
	} elsif ($state == $HITS && (m@</font></dl>@i)) {
	    print STDERR "PARSE(HITS->TRAILER): $_\n\n" if ($self->{_debug} >= 2);
	    $state = $TRAILER;
	} elsif ($state == $TRAILER && m@<a href="([^"]+)">next\<\/a\>(.*)@i) { 
	    my($relative_url) = $1;
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    print STDERR "PARSE(TRAILER->POST_NEXT): $_\n\n" if ($self->{_debug} >= 2);
	    $state = $POST_NEXT;
	} else {
            print STDERR "PARSE: read:\"$_\"\n" if ($self->{_debug} >= 2);
	};
    };
    if ($state != $POST_NEXT) {
	# end, no other pages (missed ``next'' tag)
	if (defined($hit)) {
	    push(@{$self->{cache}}, $hit);
	};
	$self->{_next_url} = undef;
    };
    # sleep so as to not overload server
    $self->user_agent_delay if (defined($self->{_next_url}));
    return $hits_found;
}
1;


