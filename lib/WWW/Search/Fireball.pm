#!/usr/local/bin/perl -w

#
# Fireball.pm
# by Andreas Borchert
# nearly everything has been shamelessly copied from:
#
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Fireball.pm,v 1.1 1999/06/18 19:15:36 mthurn Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::Fireball;

=head1 NAME

WWW::Search::Fireball - class for searching Fireball


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Fireball');


=head1 DESCRIPTION

This class is an Fireball specialization of WWW::Search.
It handles making and interpreting Fireball searches
F<http://www.fireball.de>.

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


=head1 AUTHOR

C<WWW::Search::Fireball> has been shamelessly copied by
Andreas Borchert, <borchert@mathematik.uni-ulm.de> from
C<WWW::Search::AltaVista> by John Heidemann, <johnh@isi.edu>.


=head1 COPYRIGHT

The original parts from John Heidemann are subject to
following copyright notice:

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
	# defaults:
	# http://www.fireball.de/query-fireball.fcg?action=query&pg=express&q=Jobwunder&what=german_web&fmt=d
	$self->{_options} = {
	    'action' => 'query',
	    'pg' => 'express',
	    'what' => 'german_web',
	    'fmt' => 'd',
	    'search_url' => 'http://www.fireball.de/query-fireball.fcg',
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
    print STDERR "WWW::Search::Fireball::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    my($HEADER, $HITS, $TRAILER, $POST_NEXT, $FINISH) = (1..10);  # order matters
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit) = undef;
    my($raw) = '';
    foreach ($self->split_lines($response->content())) {
        next if m@^$@; # short circuit for blank lines
	if ($state == $HEADER &&
	       /^Keine passenden Dokumente gefunden/) {
	    $self->approximate_result_count(0);
	    print STDERR "PARSE(2:HEADER->TRAILER): no documents found.\n" if ($self->{_debug} >= 2);
	    $state = $FINISH;
        }
	elsif ($state == $HEADER &&
	       /^Dokument\s+\d+\-\d+\s+von ([0-9.]+) Treffern/ ) {
	    # current variants:
	    # Dokument 1-10 von 221 Treffern, beste Treffer zuerst.
	    # Keine passenden Dokumente gefunden

	    my($n) = $1;
	    $n =~ s/\.//g;
	    $self->approximate_result_count($n);
	    $state = $HITS;
	    print STDERR "PARSE(2:HEADER->HITS): $n documents found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS &&
	      m{
	         ^<tr><td.*?<b>
		 <a\shref="(.*?)">           # $1: URL
		 <font.*?>(.*?)</font>       # $2: title
		 </a>
		 .*?
		 <font.*?>(.*?)<br></font>   # $3: description
		 .*
		 -\s(\d+\.\d+\.\d{4})\s+     # $4: date
		 </i><br><br></font>
		 </td></tr>
	      }xi) {
	    # actual line:
	    # <TR><td valign="top" WIDTH="25" bgcolor="#CC0000"><img SRC="bilder/verschiedenes/1.gif" BORDER="0" width="25" height="1">&nbsp;</td><td bgcolor="#FFFFCC"><b><a HREF="http://www.kostenlos.de/wwwboard/produkteforum/messages/153.html"><font FACE="Arial,Helvetica" SIZE="2">Re: Das Jobwunder, nebenher von zu Hause arbeiten. Der Megatre</font></a></b></td></tr><tr><td valign="top" WIDTH="25"><img src="bilder/verschiedenes/1.gif" width="21" height="1"></td><td><font FACE="Arial,Helvetica" SIZE="2">Re: Das Jobwunder, nebenher von zu Hause arbeiten. Der Megatrend!!! [ Antworten zeigen ] [ Antwort schreiben ] [ Kostenlos.de - Produkte-Forum  ]  Geschrieben von Lothar Bauer am September 08, 1998 um 10:41:03:  Als Antwort auf: Re: Das Jobwunder, n<br></font><font FACE="Arial,Helvetica" SIZE="1"><a HREF="http://www.kostenlos.de/wwwboard/produkteforum/messages/153.html">http://www.kostenlos.de/wwwboard/produkteforum/messages/153.html</a><BR><i>Gr&ouml;&szlig;e 2 K - 8.9.1998  </i><br><br></font></td></tr>

	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $raw .= $_;
	    $hit->add_url($1);
	    $hits_found++;
	    my($title) = $2;
	    $title =~ s/<[^>]+>//g;   # strip any accidental formatting in title
	    $hit->title($title);
	    $hit->change_date($4);
	    $hit->description($3);
	    print STDERR "PARSE(3:HITS): hit found.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@^<!--- end hits --->@i) {
	    # end of hits
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $state = $TRAILER;
	    print STDERR "PARSE(6b:HITS->TRAILER).\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS) {
	    # other random stuff in a hit---accumulate it
	    $raw .= $_;
	} elsif ($state == $TRAILER &&
	       m{
	          ^\s*<td
		  .*?
		  <a\shref="(.*?\?.*?)"
		  .*?
		  n\&auml;chste\sSeite
	       }ix) {
	    # set up next page
	    # <td bgcolor="#FFCC00"><font face="arial,helvetica" size="2"><b><A HREF="/query-fireball.fcg?action=query&pg=express&fmt=d&r=&q=Jobwunder&stq=11&d0=&d1=&what=german_web" TARGET=_top>n&auml;chste Seite</A> </b></font></td>

	    my($relative_url) = $1;
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    $state = $POST_NEXT;
	    print STDERR "Next URL: $self->{_next_url}\n" if ($self->{_debug} >= 2);
	    print STDERR "PARSE(9a:TRAILER->POST_NEXT): found next.\n" if ($self->{_debug} >= 2);
	} else {
	    # accumulate raw
	    $raw .= $_;
	    print STDERR "PARSE(RAW): $_\n" if ($self->{_debug} >= 3);
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

    # sleep so as to not overload fireball
    # $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;