#!/usr/local/bin/perl -w

#
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996-1997 by USC/ISI
# $Id: AltaVista.pm,v 1.23 1997/10/08 23:02:30 johnh Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::AltaVista;

=head1 NAME

WWW::Search::AltaVista - class for searching Alta Vista 

=head1 DESCRIPTION

This class is an AltaVista specialization of WWW::Search.
It handles making and interpreting AltaVista searches
F<http://www.altavista.digital.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 OPTIONS

The default is for simple web queries.
Specialized back-ends for simple and advanced web and news searches
are available (see
L<WWW::Search::AltaVista::Web>,
L<WWW::Search::AltaVista::AdvancedWeb>,
L<WWW::Search::AltaVista::News>,
L<WWW::Search::AltaVista::AdvancedNews>).
These back-ends set different combinations following options.

=over 8

=item search_url=URL

Specifies who to query with the AltaVista protocol.
The default is at
C<http://www.altavista.digital.com/cgi-bin/query>;
you may wish to retarget it to
C<http://www.altavista.telia.com/cgi-bin/query>
or other hosts if you think that they're ``closer''.

=item search_debug, search_parse_debug, search_ref
Specified at L<WWW::Search>.

=item pg=aq

Do advanced queries.
(It defaults to simple queries.)

=item what=news

Search Usenet instead of the web.
(It defaults to search the web.)

=back


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

C<WWW::Search::AltaVista> is written and maintained
by John Heidemann, <johnh@isi.edu>.


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
# ./altavista.pl xxxasdf                        --- no hits
# ./altavista.pl '"lsam replication"'           --- single page return
# ./altavista.pl '+"john heidemann" +work'      --- 9 page return
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


sub undef_to_emptystring {
    return defined($_[0]) ? $_[0] : "";
}


# private
sub native_setup_search
{
    my($self, $native_query, $native_options_ref) = @_;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 0;
    # set the text=yes option to provide next links with <a href>
    # (suggested by Guy Decoux <decoux@moulon.inra.fr>).
    if (!defined($self->{_options})) {
	$self->{_options} = {
	    'pg' => 'q',
	    'text' => 'yes',
	    'what' => 'web',
	    'fmt' => 'd',
	    'search_url' => 'http://www.altavista.digital.com/cgi-bin/query',
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
sub begin_new_hit
{
    my($self) = shift;
    my($old_hit) = shift;
    my($old_raw) = shift;

    # Save the hit we were working on.
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

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    print STDERR "WWW::Search::AltaVista::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    my($HEADER, $HITS, $TRAILER, $POST_NEXT) = (1..10);  # order matters
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit) = undef;
    my($raw) = '';
    foreach (split(/\n/, $response->content())) {
         next if m@^$@; # short circuit for blank lines
	 if ($state == $HEADER && /Documents?.*of\s*(about)?\s*(\d+)\s+matching/) {   # prior to July 1997
	    $self->approximate_result_count($2);
	    $state = $HITS;
	    print STDERR "PARSE(1:HEADER->HITS): $2 documents found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HEADER && /(<b>)?(no|\d+)<\/b>\s+documents? match/i) {  # post July 1997
	    my($n) = $2;
	    $n = 0 if ($n =~ /no/i);
	    $self->approximate_result_count($n);
	    $state = $HITS;
	    print STDERR "PARSE(2:HEADER->HITS): $n documents found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@^(<p><dt>|<dt>).*<a href=\"([^"]+)"><strong>(.*)</strong></a><dd>(.*)(\.)?<br>@i) {  # post July 1997
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $raw .= $_;
	    $hit->add_url($2);
	    $hits_found++;
	    $hit->title($3);
	    $hit->description(undef_to_emptystring($4) . undef_to_emptystring($5));
	    print STDERR "PARSE(3:HITS): hit found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@^(<[Pp]><dt>|<dt>)<a href=\"([^"]+)"><strong>(.*)</strong></a><dd>(.*)<br><a href=\"([^"]+)">@) {
	    # news is slightly different
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $raw .= $_;
	    $hit->add_url($2);   # AltaVista's news gateway URL
	    $hits_found++;
	    $hit->title($3);
	    $hit->description(undef_to_emptystring($4));
	    $hit->add_url(undef_to_emptystring($5));   # news: URL
	    $hits_found++;
	    print STDERR "PARSE(4:HITS): news hit found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && /^<cite><a href="([^"]+)">/) { #"
	    if (defined($hit)) {
		$raw .= $_;
	        $hit->add_url($1);
	        $hits_found++;   # altavista counts URL==hit
	    };
	    print STDERR "PARSE(5:HITS): additional hit found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && /^<b>[Tt]ip:/) {
	    # end, with a list of other pages to go to
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $state = $TRAILER;
	    print STDERR "PARSE(6:HITS->TRAILER).\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && /^<CENTER>.*\s+p\./) {   # pre july 97
	    # end, with a list of other pages to go to
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    if (/\[[Nn]ext\]/) {
		# set up next page
		my($relative_url) = m@<a\s+href="([^"]+)">\s*\[\s*[Nn]ext\s*\]\s*</a>@; #"
		$self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    } else {
		$self->{_next_url} = undef;
	    };
	    $state = $POST_NEXT;
	    print STDERR "PARSE(7:HITS->POST_NEXT).\n" if ($self->{_debug} >= 2);
	} elsif ($state == $TRAILER && /\>\[[Nn]ext\]\</) {
	    # set up next page
	    my($relative_url) = m@<a\s+href="([^"]+)">\s*\[\s*[Nn]ext\s*\]\s*</a>@; # "
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    $state = $POST_NEXT;
	    print STDERR "PARSE(7:TRAILER->POST_NEXT): found next.\n" if ($self->{_debug} >= 2);
	} else {
	    # accumulate raw
	    $raw .= $_;
	};
    };
    if ($state != $POST_NEXT) {
	# end, no other pages (missed ``next'' tag)
	if ($state == $HITS) {
	    $self->begin_new_hit($hit, $raw);   # save old one
	    print STDERR "PARSE: never got to TRAILER.\n" if ($self->{_debug} >= 2);
	};
	$self->{_next_url} = undef;
    };

    # sleep so as to not overload altavista
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
