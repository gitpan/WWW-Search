#!/usr/local/bin/perl -w

#
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996-1998 by USC/ISI
# $Id: AltaVista.pm,v 1.3 1999/09/30 19:38:35 mthurn Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::AltaVista;

=head1 NAME

WWW::Search::AltaVista - class for searching Alta Vista 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('AltaVista');


=head1 DESCRIPTION

This class is an AltaVista specialization of WWW::Search.
It handles making and interpreting AltaVista searches
F<http://www.altavista.com>.

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
C<http://www.altavista.com/cgi-bin/query>;
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
	$self->{_options} = {
	    'pg' => 'q',
	    'text' => 'yes',
	    'what' => 'web',
	    'fmt' => 'd',
	    'search_url' => 'http://www.altavista.com/cgi-bin/query',
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
    foreach ($self->split_lines($response->content())) {
        next if m@^$@; # short circuit for blank lines
	if (0) {
	} elsif ($state == $HEADER && (/(no|[0-9,]+)[< ].*match.*found/i || /AltaVista\s+found.*[^,0-9](no|[0-9,]+)\s+(Web|document|posting)/i)) {
	    # post 30-May-98
	    # <font size=-1>No matches were found.</font><P><font size=-1><dl>
	    # <font size=-1><b>10</b> matches were found. </font><P><font size=-1><P>
	    # <td valign=top bgcolor=#ffffff><table border=0 width=434 bgcolor=#ffffff height=100% cellpadding=4 cellspacing=0><tr><td valign=top><font face=helvetica size=-1><font face=helvetica size=-1>About <b>14,115,615</b> matches were found. </font><P></font><font face=helvetica size=-1>
	    #
	    # afb 10/98 change
	    my($n) = $1;
	    $n =~ s/,//g;
	    $n = 0 if ($n =~ /no/i);
	    $self->approximate_result_count($n);
	    $state = $HITS;
	    print STDERR "PARSE(2:HEADER->HITS): $n documents found.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@(<p><dt>|<dt>|<dt><b>)[^"]*\d+\.[^"]*<a[^>]*href=\"([^"]+)"[^>]*>(.*)</a>.*<dd>\s+(\d+\s+\w+\s+\d+)([^"]+)<a@i) {  # post 30-May-98 "
	    # news is, of course, slightly different
	    # <dt><b>1. </b><a href="http://ww2.altavista.digital.com/cgi-bin/news?msg@96138@comp%2elang%2eperl%2emisc"><strong>How to Tar &amp; unzip Perl mods on CPAN site on Win32?</strong></a><dd> 8 Jan 98 - <b>comp.lang.perl.misc</b><br><a href="news:34B53D7D.2CED@fast.net">&lt;34B53D7D.2CED@fast.net&gt;</a><br>  <a href="mailto:emorr@fast.net">&quot;Edward Morris, Jr.&quot; &lt;emorr@fast.net&gt;</a><P>
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $raw .= $_;
	    $hit->add_url($2);
	    $hits_found++;
	    my($title) = $3;
	    $title =~ s/<[^>]+>//g;   # strip any accidental formatting in title
	    $hit->title($title);
	    $hit->change_date($4);
	    $hit->description($5);
	    print STDERR "PARSE(3:HITS): news hit found.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@(<p><dt>|<dt>|<dt><b>)[^"]*\d+\.[^"]*<a[^>]*href=\"([^"]+)"[^>]*>(.*)</a>@i) {
	    # post 30-May-98:
	    # <dt><b>1. </b><a href="http://www.isi.edu/lsam/tools/autosearch/"><b>index.html directory page</b></a><dd>
	    # post  6-Oct-98:
 	    # <dl><dt><b>12. </b><a href="http://www.zum.de/schule/Faecher/G/BW/Landeskunde/rhein/zisterz/zs_skrp2.htm"><b>Das Skriptorium der Zisterzienser</b></a><dd>
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $raw .= $_;
	    $hit->add_url($2);
	    $hits_found++;
	    my($title) = $3;
	    $title =~ s/<[^>]+>//g;   # strip any accidental formatting in title
	    $hit->title($title);
	    $hit->description("");
	    print STDERR "PARSE(3:HITS): hit found.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@^([^<]+).*last modified\s+(\S+)\s.*page size\s+(\S+)\s@i) { # "
	    # pre-8-oct-98
	    # AutoSearch WEB Searching. What is AutoSearch? AutoSearch performs a web-based search and puts the results set in a web page. It periodically updates this..<br><font size=-2>Last modified 3-Feb-97 - page size 2K - in English [ <a href="http://babelfish.altavista.digital.com/cgi-bin/translate?urltext=http%3a%2f%2fwww%2eisi%2eedu%2flsam%2ftools%2fautosearch%2f&language=en">Translate</a> ]</font><P>
	    $raw .= $_;
	    $hit->description($1);
	    $hit->change_date($2);
	    my($size) = $3;
	    $size *= 1024 if ($size =~ s@k$@@i);
	    $size *= 1024*1024 if ($size =~ s@m$@@i);
	    $hit->size($size);
	    print STDERR "PARSE(3old:HITS): hit found.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@last modified (\d+-\w+-\d+).*page size (\S+)@i) {
	    # post  8-Oct-98
	    # Last modified 3-Jun-98 - page size 2K - in English</font> [&nbsp;<a href="http://jump.altavista.com/trans.go??urltext=http%3a%2f%2fwww%2eisi%2eedu%2f%7elsam%2ftools%2fautosearch%2findex%2ehtml&language=en">Translate</a>&nbsp;]</dl>
	    $raw .= $_;
	    $hit->change_date($1);
	    my($size) = $2;
	    $size *= 1024 if ($size =~ s@k$@@i);
	    $size *= 1024*1024 if ($size =~ s@m$@@i);
	    $hit->size($size);
	    print STDERR "PARSE(4old:HIT DATE): hit found.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && m@^([^<]+).*URL:@) {
	    # post  8-Oct-98
	    # AutoSearch WEB Searching. What is AutoSearch? AutoSearch performs a web-based search and puts the results set in a web page. It periodically updates this..<br><b>URL:</b> <font color=gray>www.isi.edu/~lsam/tools/autosearch/index.html<br>
	    $raw .= $_;
	    $hit->description($1);
	    print STDERR "PARSE(5:DESCRIPTION): hit found.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS && (m@^</font>.*<br>@i || m@AltaVista Home.*\|@i || m@result pages:.*href="/cgi-bin/query@i)) { #"
	    # end of hits
	    # afb 10/98 adds the cgi-bin termination check
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $state = $TRAILER;
	    print STDERR "PARSE(6b:HITS->TRAILER).\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $HITS) {
	    # other random stuff in a hit---accumulate it
	    # <font size=-2>[<b>URL:</b> www.isi.edu/lsam/tools/autosearch/]</font><br>
	    $raw .= $_;
	    print STDERR "PARSE(7:HITS NO MATCH)\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 2);
	} elsif ($state == $TRAILER && /<a[^>]+href="([^"]+)".*\&gt;\&gt;/) { # "
	    # set up next page
	    # <a href="/cgi-bin/query?pg=q&text=yes&q=%2bLSAM+%2bISI+%2bwork&stq=10&c9k">[<b>&gt;&gt;</b>]</a> <P>
	    my($relative_url) = $1;
	    # hack:  make sure fmt=d stays on news URLs
	    $relative_url =~ s/what=news/what=news\&fmt=d/ if ($relative_url !~ /fmt=d/);
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    $state = $POST_NEXT;
	    print STDERR "PARSE(9a:TRAILER->POST_NEXT): found next.\n" if ($self->{_debug} >= 2);
	} elsif ($state == $TRAILER && /\>\[[Nn]ext\]\</) {
	    # this section is pre 30-May-98 and should be deleted
	    # set up next page
	    my($relative_url) = m@<a\s+href="([^"]+)">\s*\[\s*[Nn]ext\s*\]\s*</a>@; # "
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    $state = $POST_NEXT;
	    print STDERR "PARSE(9b:TRAILER->POST_NEXT): found next.\n" if ($self->{_debug} >= 2);
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

    # sleep so as to not overload altavista
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
