#!/usr/local/bin/perl -w

#
# Lycos.pm
# by Wm. L. Scheding
# Copyright (C) 1996 by USC/ISI
# $Id: Lycos.pm,v 1.3 1996/11/21 23:02:17 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Lycos;

=head1 NAME

WWW::Search::Lycos - class for searching Lycos 

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
require WWW::SearchResult;



# private
sub native_setup_search
{
    my($self, $native_query) = @_;
    $self->user_agent();
    $self->{_next_to_retrieve} = 0;
    $self->{_base_url} = $self->{_next_url} =
	"http://www.lycos.com/cgi-bin/pursuit?cat=lycos&x=13&y=15" .
	"&query=" . $native_query;
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
    my($HEADER, $HITS, $DD, $DESC, $CENTER, $PREV, $NBSP, $NEXT, $TRAILER) = (1..10);
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit) = ();
    foreach (split(/\n/, $response->content())) {
        next if m@^$@; # short circuit for blank lines
	if ($state == $HEADER && m@^<P>\s+You\s+found\s+(\d+)\s+relevant\s+documents@i) {
#            print STDOUT "header:\"$_\"\n";
	    $self->approximate_result_count($1);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^<DT><b>(\d+)\)\s+<a href=\"([^"]+)\">(.*)</a></b>@i) { #"
#            print STDOUT "hit:\"$_\"\n";
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $hit = new WWW::SearchResult;
	    $hit->add_url($2);
	    $hits_found++;
	    $hit->title($3);
	    $state = $DD;
	} elsif ($state == $DD && m@^<DD>\s+@i) { #"
#            print STDOUT "DD:\"$_\"\n";
	    $state = $DESC;
	} elsif ($state == $DESC && m@^(.*)$@i) { #"
#            print STDOUT "DESC:\"$_\"\n";
	    $hit->description($1);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^<CENTER>$@i) { #"
#            print STDOUT "center:\"$_\"\n";
	    $state = $CENTER;
	} elsif ($state == $CENTER && m@^Previous Page$@i) { #"
#            print STDOUT "prev:\"$_\"\n";
	    $state = $PREV;
	} elsif ($state == $CENTER && m@^<A HREF="([^"]+)">Previous Page</A>$@i) { #"
#            print STDOUT "prev:\"$_\"\n";
	    $state = $PREV;
	} elsif ($state == $PREV && m@^&nbsp;&nbsp;$@i) { #"
#            print STDOUT "nbsp:\"$_\"\n";
	    $state = $NBSP;
	} elsif ($state == $NBSP && m@<A HREF="([^"]+)">Next Page</a><BR>@i) { #"
#            print STDOUT "next:\"$_\"\n";
	    # end, with a list of other pages to go to
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    # set up next page
    	    my($relative_url) = $1; #"
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    $state = $TRAILER;
	} elsif ($state == $NBSP && m@^Next Page<BR>$@i) { #"
#            print STDOUT "last:\"$_\"\n";
	    # end, with no other pages to go to
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $self->{_next_url} = undef;
	    $state = $TRAILER;
	} else {
#            print STDOUT "read:\"$_\"\n";
	};
    };
    if ($state != $TRAILER) {
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
