#!/usr/local/bin/perl -w

#
# Yahoo.pm
# by Wm. L. Scheding
# Copyright (C) 1996 by USC/ISI
# $Id: Yahoo.pm,v 1.4 1996/11/21 23:02:17 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Yahoo;

=head1 NAME

WWW::Search::Yahoo - class for searching Yahoo 

=head1 DESCRIPTION

WARNING:  This class has not been fully debugged yet.
Use at your own risk.

This class is an Yahoo specialization of WWW::Search.
It handles making and interpreting Yahoo searches
F<http://www.yahoo.com>.

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

C<WWW::Search::Yahoo> does not currently work reliably
and is not being actively maintained.
If you wish to hack on it, please go ahead.


=head1 AUTHOR

C<WWW::Search::Yahoo> is written by Wm. L. Scheding
based upon C<WWW::Search::AltaVista>.


=head1 COPYRIGHT

Copyright (c) 1996 University of Southern California.
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
# ./yahoo.pl 'xxxxasdf'         --- no hits
# ./yahoo.pl 'repographics      --- 2 hits 
# ./yahoo.pl 'reprographics     --- 33 hits 
# ./yahoo.pl 'replication       --- 73 hits 
# ./yahoo.pl 'reproduction      --- 255 hits 
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
# $VERSION = 1.000;
@ISA = qw(WWW::Search Exporter);

use Carp ();
require WWW::SearchResult;

# alta vista via yahoo
# http://av.yahoo.com/bin/search?p=lsam+replication&d=y&g=0&s=a&w=s&n=100
# plain old yahoo, words (not substrings)
# http://search.yahoo.com/bin/search?p=replication&d=y&g=0&s=a&w=w&n=100
# private
sub native_setup_search
{
    my($self, $native_query) = @_;
    $self->user_agent();
    $self->{_next_to_retrieve} = 0;
    $self->{_base_url} = $self->{_next_url} =
	"http://search.yahoo.com/bin/search?d=y&g=0&s=a&w=s&n=100" .
	"&p=" . $native_query;
}


# private
sub native_retrieve_some
{
    my ($self) = @_;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    my($request) = new HTTP::Request('GET', $self->{_next_url});
    my($response) = $self->{user_agent}->request($request);
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    my($HEADER, $HITS, $TRAILER) = (1..10);
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($cite) = "";
    my($hit) = ();
    foreach (split(/\n/, $response->content())) {
        next if m@^$@; # short circuit for blank lines
	if ($state == $HEADER && m@<center>Found\s+(\d+)\s+matches\s+containing\s*<b>(.*)</b>\.\s+$@i) {
#	    print STDOUT "header:\"$_\"\n";
	    $self->approximate_result_count($1); # search is $2
	    $state = $HITS;
	} elsif ($state == $HITS && m@^<a href=\"([^"]+)">(.*)</a>(.*)<ul>@i) { #"
#	    print STDOUT "cite:\"$_\"\n";
	    $cite = $1; # in Yahoo the cites are first, then the URLs
	} elsif ($state == $HITS && m@^<li><a href="([^"]+)">(.*)</a>(.*)$@i) { #"
#	    print STDOUT "hits:\"$_\"\n";
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $hit = new WWW::SearchResult;
	    $hit->add_url($1);
	    $hits_found++;
	    $hit->title($2);
	    $hit->description($3);
	    if ($cite) { # add cites
	      $hit->add_url($cite);
	      $hits_found++;   # yahoo has cite first
	    }
	} elsif ($state == $HITS && m@^<center>@) {
#	    print STDOUT "next:\"$_\"\n";
	    # end, with a list of other pages to go to
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    if (m@<b><a href="([^"]+)">Next\s+(\d*)\s+Matches</a>@i) {
		# set up next page
		my($relative_url) = $1; #"
		$self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    } else {
		$self->{_next_url} = undef;
	    };
	    $state = $TRAILER;
	} else {
#	    print STDOUT "read:\"$_\"\n";
	};
    };
    if ($state != $TRAILER) {
	# end, no other pages (missed ``next'' tag)
	if (defined($hit)) {
	    push(@{$self->{cache}}, $hit);
	};
	$self->{_next_url} = undef;
    };

    # sleep so as to not overload yahoo
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
