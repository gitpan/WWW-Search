#!/usr/local/bin/perl -w

#
# Excite.pm
# by GLen Pringle
#
# based upon Lycos.pm
# by Wm. L. Scheding
# Copyright (C) 1996 by USC/ISI
# $Id: Excite.pm,v 1.5 1996/11/25 19:43:10 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Excite;

=head1 NAME

WWW::Search::Excite - class for searching Excite 

=head1 DESCRIPTION

This class is an Excite specialization of WWW::Search.
It handles making and interpreting Excite searches
F<http://www.excite.com>.

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

This module should support options and a back-end specific for news.


=head1 AUTHOR

C<WWW::Search::Excite> is written by GLen Pringle (C<pringle@cs.monash.edu.au>)
based upon C<WWW::Search::Lycos>.


=head1 COPYRIGHT

This back-end was contributed to USC/ISI by GLen Pringle.

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
# search xxxasdf                    --- no matches
# search 'lsam AND replication'     --- four matches
# search 'glen AND pringle'         --- tons of matches
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
	"http://www.excite.com/search.gw?trace=a&collection=web" .
	"&search=" . $native_query;
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
    my($HEADER, $HITS, $DESC, $FORM, $INPUT, $TRAILER) = (1..6);
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit) = ();
    my($next) = "";
    foreach (split(/\n/, $response->content())) {
        next if m@^$@; # short circuit for blank lines
	if ($state == $HEADER && m@^<B>Excite\s+Search\s*</B>\s*found\s+<B>\s*(\d+)\s*</B>\s*documents\s+about@i) {
#            print STDOUT "header:\"$+\" matches\n";
	    $self->approximate_result_count($1);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^<DT><font\s+color=\#ff0000><B>(\d+)\%\s+</B></font><B><a href=\"([^"]+)\">(.*)</a></b>@i) { #"
#            print STDOUT "hit: \"$_\"\n";
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $hit = new WWW::SearchResult;
	    $hit->add_url($2);
	    $hits_found++;
	    $hit->title($3);
	    $state = $DESC;
	} elsif ($state == $DESC && m@^<BR><B><I>Summary:</I></B>\s+(.*)<p>$@i) { #"
#            print STDOUT "desc:\"$+\"\n";
	    $hit->description($1);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^</DL>$@i) { #"
#            print STDOUT "hits:\"$_\"\n";
	    $state = $FORM;
	} elsif ($state == $FORM && m@^<FORM\sACTION="([^"]+)"@i) { #"
#            print STDOUT "form:\"$_\"\n";
	    $state = $INPUT;
		$next = "http://www.excite.com".$1."?";
	} elsif ($state == $INPUT && m@^<INPUT\s+TYPE=(\w*)\s+NAME="*([^"]+)"*\s+VALUE=\"([^"]+)\">$@i) { #"
#            print STDOUT "input:\"$_\"\n";
		my($type) = $1;
		my($name) = $2;
		my($value) = $3;
		my($test) = $1.$3;
		if ($test !~ /^submit.*previous/i) {
			$next = "$next$name=$value&";
		}
	} elsif ($state == $INPUT && m@^</FORM>$@i) { #"
		$next =~ s/ /+/g;
		my($c) = chop($next);
		if ($c ne "&") { $next = $next.$c; }
#            print STDOUT "input:\"$_\"\n";
	    # end, with a list of other pages to go to
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    # set up next page
	    $self->{_next_url} = $next;
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

    # sleep so as to not overload excite
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
