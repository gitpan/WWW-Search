#!/usr/local/bin/perl -w

#
# Lycos.pm
# by Wm. L. Scheding, John Heidemann
# Copyright (C) 1996-1997 by USC/ISI
# $Id: Lycos.pm,v 1.8 1998/05/28 04:05:40 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Lycos;

=head1 NAME

WWW::Search::Lycos - class for searching Lycos 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Lycos');


=head1 DESCRIPTION

This class is an Lycos specialization of WWW::Search.
It handles making and interpreting Lycos searches
F<http://www.lycos.com>.

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

This module should support options.


=head1 AUTHOR

C<WWW::Search::Lycos> is written by Wm. L. Scheding
based upon C<WWW::Search::AltaVista>.
It is now maintained by John Heidemann.


=head1 COPYRIGHT

Copyright (c) 1996-1997 University of Southern California.
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

#
#  Test cases:
# ./search.pl xxxasdf         --- no hits
# ./search.pl 'lsam replication&matchmode=and'  --- single page return
# ./search.pl 'scheding'      --- 3 page return
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
# $VERSION = 1.000;
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
	    'cat' => 'lycos',
	    'matchmode' => 'and',
	    'adv' => '0',
	    'search_url' => 'http://www.lycos.com/cgi-bin/pursuit',
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
	"query=" . $native_query;
    print $self->{_base_url} . "\n" if ($self->{_debug});
}


# private
sub native_retrieve_some
{
    my ($self) = @_;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    print STDERR "WWW::Search::Lycos::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
#    my($request) = $self->http_request('GET', $self->{_next_url});
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    my($HEADER, $HITS, $DESC, $RATING, $TRAILER, $POST_NEXT) = (1..10);
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit, $raw, $title, $url, $rating, $desc) = ();
    foreach (split(/\n/, $response->content())) {
        next if m@^$@; # short circuit for blank lines
	if ($state == $HEADER && m@\s+of.*(\d+).*relevant\s+result@i) { # new as of  7-Oct-97
	    $self->approximate_result_count($1);
            print STDERR "PARSE(HEADER->HITS-1): $_\n" if ($self->{_debug} >= 2);
	    $state = $HITS;
	} if ($state == $HEADER && m@matching web pages@i) {  # new as of 23-Mar-98
            print STDERR "PARSE(HEADER->HITS-2): $_\n" if ($self->{_debug} >= 2);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^<a href="([^"]+)">(.*)\<\/a\>@i) { # post 23-Mar-98 "
	    $raw = $_;
	    $url = $1;
	    $title = $2;
	    print STDERR "PARSE(HITS->DESC): $_\n" if ($self->{_debug} >= 2);
	    $state = $DESC;
	} elsif ($state == $DESC) {
	    $raw .= $_;
	    m@<br>(.*)@;
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
	} elsif ($state == $HITS && (m@-- end formatted results --@ || m@</DL>@i)) {
	    print STDERR "PARSE(HITS->TRAILER): $_\n\n" if ($self->{_debug} >= 2);
	    $state = $TRAILER;
	} elsif ($state == $TRAILER &&  m@<A HREF="([^"]+)">Next Page</A>@i) { #"
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

    # sleep so as to not overload lycos
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
