#
# NL.pm
# by Erik Smit
# Copyright (C) 1996-1998 by USC/ISI
# Copyright (C) 2001 by Different Soft
# $Id: NL.pm,v 1.0 2001/15/03 16:48:51 esmit Exp $
#
# Complete copyright notice follows below.
#


package WWW::Search::AltaVista::NL;

=head1 NAME

WWW::Search::AltaVista::NL - class for searching the dutch version of Alta Vista 


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('AltaVista::NL');


=head1 DESCRIPTION

This class is an modified version of the AltaVista specialization of WWW::Search.
It handles making and interpreting Dutch AltaVista searches
F<http://nl.altavista.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 OPTIONS

The default is for simple web queries.

=over 8

=item search_url=URL

Specifies who to query with the AltaVista protocol.
The default is at
C<http://nl.altavista.com/cgi-bin/query>;

=item search_debug, search_parse_debug, search_ref
Specified at L<WWW::Search>.

=item pg=aq

Do advanced queries.
(It defaults to simple queries.)

=back


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>,


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


=head1 AUTHOR and CURRENT VERSION

C<WWW::Search::AltaVista::NL> is written and maintained
by Erik Smit, <zoiah@zoiah.nl>.

The best place to obtain C<WWW::Search::AltaVista::NL>
is from Martin Thurn's WWW::Search releases on CPAN.
Because AltaVista sometimes changes its format
in between his releases, sometimes more up-to-date versions
can be found at
F<http://www.zoiah.nl/programming/AltaVistaNL/index.html>.


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
# note that the AltaVistaNL version number is not synchronized
# with the WWW::Search version number.
$VERSION = '1.0';
#'

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
	    'what' => 'nl',
	    'fmt' => 'd',
	    'search_url' => 'http://nl.altavista.com/cgi-bin/query',
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
    # (Now in sorted order for consistency regarless of hash ordering.)
    my($options) = '';
    foreach (sort keys %$options_ref) {
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
    print STDERR $self->{_base_url} . "\n" if ($self->{_debug});
}

# private
sub save_old_hit {
    my($self) = shift;
    my($old_hit) = shift;
    my($old_raw) = shift;

    if (defined($old_hit)) {
	$old_hit->raw($old_raw) if (defined($old_raw));
	push(@{$self->{cache}}, $old_hit);
    };

    return(undef, undef);
}

# private
sub begin_new_hit
{
    my($self) = shift;
    my($old_hit) = shift;
    my($old_raw) = shift;

    $self->save_old_hit($old_hit, $old_raw);

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
    print STDERR "WWW::Search::AltaVistaNL::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

# parse the output
    my($HEADER, $HITS, $INHIT, $TRAILER, $POST_NEXT) = (1..10);  # order matters
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit) = undef;
    my($raw) = '';
    foreach ($self->split_lines($response->content())) {
        next if m@^$@; # short circuit for blank lines
	######
	# HEADER PARSING: find the number of hits
	#
	if (0) {
	} elsif ($state == $HEADER && /AltaVista vond geen documenten voor uw zoekbewerking/i) {
	    # 25-Oct-99
	    $self->approximate_result_count(0);
	    $state = $TRAILER;
	    print STDERR "PARSE(10:HEADER->HITS): no documents found.\n" if ($self->{_debug} >= 2);
        ######
	} elsif ($state == $HEADER && /([\d,]+) gevonden? pagina's/i) {
	    # 25-Oct-99
	    my($n) = $1;
	    $n =~ s/,//g;
	    $self->approximate_result_count($n);
	    $state = $HITS;
	    print STDERR "PARSE(10:HEADER->HITS): $n documents found.\n" if ($self->{_debug} >= 2);
	######
	# HITS PARSING: find each hit
	#
	} elsif ($state == $HITS && /(<table width="100%" align="center">)/i) {
$state = $TRAILER;
	    print STDERR "PARSE(11:HITS->TRAILER): done.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $HITS && /<dl><dt>/i) {
	    # 25-Oct-99
	    ($hit, $raw) = $self->begin_new_hit($hit, $raw);
	    $hits_found++;
	    $raw .= $_;
	    $state = $INHIT;
	    print STDERR "PARSE(12:HITS->INHIT): hit start.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $INHIT && /^<b>URL: <\/b><FONT color="#777777">([^"]+)<br>/i) { #"
	    # 25-Oct-99
	    $raw .= $_;
	    $hit->add_url($1);
	    print STDERR "PARSE(13:INHIT): url: $1.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $INHIT && /^<a.*HREF.*>(.+)<\/a>.*<\/dt>/i) {
	    # 25-Oct-99
	    $raw .= $_;
	    my($title) = $1;
	    # $title =~ s/<\/?em>//ig;  # strip keyword emphasis (use raw if you want to get it bacK)
	    $hit->title($title);
	    print STDERR "PARSE(13:INHIT): title: $1.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $INHIT && /^<dd>(.*)<br>/i) {
	    # 25-Oct-99
	    $raw .= $_;
	    $hit->description($1);
	    print STDERR "PARSE(13:INHIT): description.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $INHIT && /^Laatste wijziging: (.*)$/i) {
	    # 25-Oct-99
	    $raw .= $_;
	    $hit->change_date($1);
	    print STDERR "PARSE(13:INHIT): mod date.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $INHIT && /^<\/dl>/i) {
	    # 25-Oct-99
	    $raw .= $_;
	    ($hit, $raw) = $self->save_old_hit($hit, $raw);
	    $state = $HITS;
	    print STDERR "PARSE(13:INHIT->HITS): end hit.\n" if ($self->{_debug} >= 2);

	} elsif ($state == $INHIT) {
	    # other random stuff in a hit---accumulate it
	    $raw .= $_;
	    print STDERR "PARSE(14:INHIT): no match.\n" if ($self->{_debug} >= 2);
            print STDERR ' 'x 12, "$_\n" if ($self->{_debug} >= 3);

	} elsif ($hits_found && ($state == $TRAILER || $state == $HITS) && /<a[^>]+href="([^"]+)".*\&gt;\&gt;/i) { # "
	    # (above, note the trick $hits_found so we don't prematurely terminate.)
	    # set up next page
	    my($relative_url) = $1;
	    # hack:  make sure fmt=d stays on news URLs
	    $relative_url =~ s/what=news/what=news\&fmt=d/ if ($relative_url !~ /fmt=d/i);
            my($n) = new URI::URL($relative_url, $self->{_base_url});
            $n = $n->abs;
            $self->{_next_url} = $n;	    $state = $POST_NEXT;
	    print STDERR "PARSE(15:->POST_NEXT): found next, $n.\n" if ($self->{_debug} >= 2);

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
 -=- MIME -=- 
  This message is in MIME format.  The first part should be readable text,
  while the remaining parts are likely unreadable without MIME-aware tools.
  Send mail to mime@docserver.cac.washington.edu for more info.

--8323328-1224416301-984674016=:23502
Content-Type: TEXT/PLAIN; charset=US-ASCII

On Thu, 15 Mar 2001, Kingpin wrote:

> > Ok, that would mean I should call it NL.pm and drop it in the AltaVista
> > directory, right?
>
> That's right.
>
> > BTW, should I send it to you as an attachment so you can review it? (and
>
> That would be great.

Here it is. :)




--8323328-1224416301-984674016=:23502
Content-Type: TEXT/PLAIN; charset=US-ASCII; name="NL.pm"
Content-Transfer-Encoding: BASE64
Content-ID: <Pine.LNX.4.30.0103151533360.23502@localhost.localdomain>
Content-Description: Altavista::NL
Content-Disposition: attachment; filename="NL.pm"

IyEvdXNyL2xvY2FsL2Jpbi9wZXJsIC13DQoNCiMNCiMgTkwucG0NCiMgYnkg
RXJpayBTbWl0DQojIENvcHlyaWdodCAoQykgMTk5Ni0xOTk4IGJ5IFVTQy9J
U0kNCiMgQ29weXJpZ2h0IChDKSAyMDAxIGJ5IERpZmZlcmVudCBTb2Z0DQoj
ICRJZDogTkwucG0sdiAxLjAgMjAwMS8xNS8wMyAxNjo0ODo1MSBlc21pdCBF
eHAgJA0KIw0KIyBDb21wbGV0ZSBjb3B5cmlnaHQgbm90aWNlIGZvbGxvd3Mg
YmVsb3cuDQojDQoNCg0KcGFja2FnZSBXV1c6OlNlYXJjaDo6QWx0YVZpc3Rh
OjpOTDsNCg0KPWhlYWQxIE5BTUUNCg0KV1dXOjpTZWFyY2g6OkFsdGFWaXN0
YTo6TkwgLSBjbGFzcyBmb3Igc2VhcmNoaW5nIHRoZSBkdXRjaCB2ZXJzaW9u
IG9mIEFsdGEgVmlzdGEgDQoNCg0KPWhlYWQxIFNZTk9QU0lTDQoNCiAgICBy
ZXF1aXJlIFdXVzo6U2VhcmNoOw0KICAgICRzZWFyY2ggPSBuZXcgV1dXOjpT
ZWFyY2goJ0FsdGFWaXN0YTo6TkwnKTsNCg0KDQo9aGVhZDEgREVTQ1JJUFRJ
T04NCg0KVGhpcyBjbGFzcyBpcyBhbiBtb2RpZmllZCB2ZXJzaW9uIG9mIHRo
ZSBBbHRhVmlzdGEgc3BlY2lhbGl6YXRpb24gb2YgV1dXOjpTZWFyY2guDQpJ
dCBoYW5kbGVzIG1ha2luZyBhbmQgaW50ZXJwcmV0aW5nIER1dGNoIEFsdGFW
aXN0YSBzZWFyY2hlcw0KRjxodHRwOi8vbmwuYWx0YXZpc3RhLmNvbT4uDQoN
ClRoaXMgY2xhc3MgZXhwb3J0cyBubyBwdWJsaWMgaW50ZXJmYWNlOyBhbGwg
aW50ZXJhY3Rpb24gc2hvdWxkDQpiZSBkb25lIHRocm91Z2ggV1dXOjpTZWFy
Y2ggb2JqZWN0cy4NCg0KDQo9aGVhZDEgT1BUSU9OUw0KDQpUaGUgZGVmYXVs
dCBpcyBmb3Igc2ltcGxlIHdlYiBxdWVyaWVzLg0KDQo9b3ZlciA4DQoNCj1p
dGVtIHNlYXJjaF91cmw9VVJMDQoNClNwZWNpZmllcyB3aG8gdG8gcXVlcnkg
d2l0aCB0aGUgQWx0YVZpc3RhIHByb3RvY29sLg0KVGhlIGRlZmF1bHQgaXMg
YXQNCkM8aHR0cDovL25sLmFsdGF2aXN0YS5jb20vY2dpLWJpbi9xdWVyeT47
DQoNCj1pdGVtIHNlYXJjaF9kZWJ1Zywgc2VhcmNoX3BhcnNlX2RlYnVnLCBz
ZWFyY2hfcmVmDQpTcGVjaWZpZWQgYXQgTDxXV1c6OlNlYXJjaD4uDQoNCj1p
dGVtIHBnPWFxDQoNCkRvIGFkdmFuY2VkIHF1ZXJpZXMuDQooSXQgZGVmYXVs
dHMgdG8gc2ltcGxlIHF1ZXJpZXMuKQ0KDQo9YmFjaw0KDQoNCj1oZWFkMSBT
RUUgQUxTTw0KDQpUbyBtYWtlIG5ldyBiYWNrLWVuZHMsIHNlZSBMPFdXVzo6
U2VhcmNoPiwNCg0KDQo9aGVhZDEgSE9XIERPRVMgSVQgV09SSz8NCg0KQzxu
YXRpdmVfc2V0dXBfc2VhcmNoPiBpcyBjYWxsZWQgYmVmb3JlIHdlIGRvIGFu
eXRoaW5nLg0KSXQgaW5pdGlhbGl6ZXMgb3VyIHByaXZhdGUgdmFyaWFibGVz
ICh3aGljaCBhbGwgYmVnaW4gd2l0aCB1bmRlcnNjb3JlcykNCmFuZCBzZXRz
IHVwIGEgVVJMIHRvIHRoZSBmaXJzdCByZXN1bHRzIHBhZ2UgaW4gQzx7X25l
eHRfdXJsfT4uDQoNCkM8bmF0aXZlX3JldHJpZXZlX3NvbWU+IGlzIGNhbGxl
ZCAoZnJvbSBDPFdXVzo6U2VhcmNoOjpyZXRyaWV2ZV9zb21lPikNCndoZW5l
dmVyIG1vcmUgaGl0cyBhcmUgbmVlZGVkLiAgSXQgY2FsbHMgdGhlIExXUCBs
aWJyYXJ5DQp0byBmZXRjaCB0aGUgcGFnZSBzcGVjaWZpZWQgYnkgQzx7X25l
eHRfdXJsfT4uDQpJdCBwYXJzZXMgdGhpcyBwYWdlLCBhcHBlbmRpbmcgYW55
IHNlYXJjaCBoaXRzIGl0IGZpbmRzIHRvIA0KQzx7Y2FjaGV9Pi4gIElmIGl0
IGZpbmRzIGEgYGBuZXh0JycgYnV0dG9uIGluIHRoZSB0ZXh0LA0KaXQgc2V0
cyBDPHtfbmV4dF91cmx9PiB0byBwb2ludCB0byB0aGUgcGFnZSBmb3IgdGhl
IG5leHQNCnNldCBvZiByZXN1bHRzLCBvdGhlcndpc2UgaXQgc2V0cyBpdCB0
byB1bmRlZiB0byBpbmRpY2F0ZSB3ZSdyZSBkb25lLg0KDQoNCj1oZWFkMSBB
VVRIT1IgYW5kIENVUlJFTlQgVkVSU0lPTg0KDQpDPFdXVzo6U2VhcmNoOjpB
bHRhVmlzdGE6Ok5MPiBpcyB3cml0dGVuIGFuZCBtYWludGFpbmVkDQpieSBF
cmlrIFNtaXQsIDx6b2lhaEB6b2lhaC5ubD4uDQoNClRoZSBiZXN0IHBsYWNl
IHRvIG9idGFpbiBDPFdXVzo6U2VhcmNoOjpBbHRhVmlzdGE6Ok5MPg0KaXMg
ZnJvbSBNYXJ0aW4gVGh1cm4ncyBXV1c6OlNlYXJjaCByZWxlYXNlcyBvbiBD
UEFOLg0KQmVjYXVzZSBBbHRhVmlzdGEgc29tZXRpbWVzIGNoYW5nZXMgaXRz
IGZvcm1hdA0KaW4gYmV0d2VlbiBoaXMgcmVsZWFzZXMsIHNvbWV0aW1lcyBt
b3JlIHVwLXRvLWRhdGUgdmVyc2lvbnMNCmNhbiBiZSBmb3VuZCBhdA0KRjxo
dHRwOi8vd3d3LnpvaWFoLm5sL3Byb2dyYW1taW5nL0FsdGFWaXN0YU5ML2lu
ZGV4Lmh0bWw+Lg0KDQoNCj1oZWFkMSBDT1BZUklHSFQNCg0KQ29weXJpZ2h0
IChjKSAxOTk2LTE5OTggVW5pdmVyc2l0eSBvZiBTb3V0aGVybiBDYWxpZm9y
bmlhLg0KQWxsIHJpZ2h0cyByZXNlcnZlZC4gICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgIA0KICAgICAgICAgICAgICAgICAg
ICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
DQpSZWRpc3RyaWJ1dGlvbiBhbmQgdXNlIGluIHNvdXJjZSBhbmQgYmluYXJ5
IGZvcm1zIGFyZSBwZXJtaXR0ZWQNCnByb3ZpZGVkIHRoYXQgdGhlIGFib3Zl
IGNvcHlyaWdodCBub3RpY2UgYW5kIHRoaXMgcGFyYWdyYXBoIGFyZQ0KZHVw
bGljYXRlZCBpbiBhbGwgc3VjaCBmb3JtcyBhbmQgdGhhdCBhbnkgZG9jdW1l
bnRhdGlvbiwgYWR2ZXJ0aXNpbmcNCm1hdGVyaWFscywgYW5kIG90aGVyIG1h
dGVyaWFscyByZWxhdGVkIHRvIHN1Y2ggZGlzdHJpYnV0aW9uIGFuZCB1c2UN
CmFja25vd2xlZGdlIHRoYXQgdGhlIHNvZnR3YXJlIHdhcyBkZXZlbG9wZWQg
YnkgdGhlIFVuaXZlcnNpdHkgb2YNClNvdXRoZXJuIENhbGlmb3JuaWEsIElu
Zm9ybWF0aW9uIFNjaWVuY2VzIEluc3RpdHV0ZS4gIFRoZSBuYW1lIG9mIHRo
ZQ0KVW5pdmVyc2l0eSBtYXkgbm90IGJlIHVzZWQgdG8gZW5kb3JzZSBvciBw
cm9tb3RlIHByb2R1Y3RzIGRlcml2ZWQgZnJvbQ0KdGhpcyBzb2Z0d2FyZSB3
aXRob3V0IHNwZWNpZmljIHByaW9yIHdyaXR0ZW4gcGVybWlzc2lvbi4NCg0K
VEhJUyBTT0ZUV0FSRSBJUyBQUk9WSURFRCAiQVMgSVMiIEFORCBXSVRIT1VU
IEFOWSBFWFBSRVNTIE9SIElNUExJRUQNCldBUlJBTlRJRVMsIElOQ0xVRElO
RywgV0lUSE9VVCBMSU1JVEFUSU9OLCBUSEUgSU1QTElFRCBXQVJSQU5USUVT
IE9GDQpNRVJDSEFOVEFCSUxJVFkgQU5EIEZJVE5FU1MgRk9SIEEgUEFSVElD
VUxBUiBQVVJQT1NFLg0KDQoNCj1jdXQNCiMnDQoNCiMjIyMjIyMjIyMjIyMj
IyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMj
IyMjIyMjIyMjIw0KDQpyZXF1aXJlIEV4cG9ydGVyOw0KQEVYUE9SVCA9IHF3
KCk7DQpARVhQT1JUX09LID0gcXcoKTsNCkBJU0EgPSBxdyhXV1c6OlNlYXJj
aCBFeHBvcnRlcik7DQojIG5vdGUgdGhhdCB0aGUgQWx0YVZpc3RhTkwgdmVy
c2lvbiBudW1iZXIgaXMgbm90IHN5bmNocm9uaXplZA0KIyB3aXRoIHRoZSBX
V1c6OlNlYXJjaCB2ZXJzaW9uIG51bWJlci4NCiRWRVJTSU9OID0gJzEuMCc7
DQojJw0KDQp1c2UgQ2FycCAoKTsNCnVzZSBXV1c6OlNlYXJjaChnZW5lcmlj
X29wdGlvbik7DQpyZXF1aXJlIFdXVzo6U2VhcmNoUmVzdWx0Ow0KDQoNCnN1
YiB1bmRlZl90b19lbXB0eXN0cmluZyB7DQogICAgcmV0dXJuIGRlZmluZWQo
JF9bMF0pID8gJF9bMF0gOiAiIjsNCn0NCg0KDQojIHByaXZhdGUNCnN1YiBu
YXRpdmVfc2V0dXBfc2VhcmNoDQp7DQogICAgbXkoJHNlbGYsICRuYXRpdmVf
cXVlcnksICRuYXRpdmVfb3B0aW9uc19yZWYpID0gQF87DQogICAgJHNlbGYt
PnVzZXJfYWdlbnQoJ3VzZXInKTsNCiAgICAkc2VsZi0+e19uZXh0X3RvX3Jl
dHJpZXZlfSA9IDA7DQogICAgIyBzZXQgdGhlIHRleHQ9eWVzIG9wdGlvbiB0
byBwcm92aWRlIG5leHQgbGlua3Mgd2l0aCA8YSBocmVmPg0KICAgICMgKHN1
Z2dlc3RlZCBieSBHdXkgRGVjb3V4IDxkZWNvdXhAbW91bG9uLmlucmEuZnI+
KS4NCiAgICBpZiAoIWRlZmluZWQoJHNlbGYtPntfb3B0aW9uc30pKSB7DQoJ
JHNlbGYtPntfb3B0aW9uc30gPSB7DQoJICAgICdwZycgPT4gJ3EnLA0KCSAg
ICAndGV4dCcgPT4gJ3llcycsDQoJICAgICd3aGF0JyA9PiAnbmwnLA0KCSAg
ICAnZm10JyA9PiAnZCcsDQoJICAgICdzZWFyY2hfdXJsJyA9PiAnaHR0cDov
L25sLmFsdGF2aXN0YS5jb20vY2dpLWJpbi9xdWVyeScsDQogICAgICAgIH07
DQogICAgfTsNCiAgICBteSgkb3B0aW9uc19yZWYpID0gJHNlbGYtPntfb3B0
aW9uc307DQogICAgaWYgKGRlZmluZWQoJG5hdGl2ZV9vcHRpb25zX3JlZikp
IHsNCgkjIENvcHkgaW4gbmV3IG9wdGlvbnMuDQoJZm9yZWFjaCAoa2V5cyAl
JG5hdGl2ZV9vcHRpb25zX3JlZikgew0KCSAgICAkb3B0aW9uc19yZWYtPnsk
X30gPSAkbmF0aXZlX29wdGlvbnNfcmVmLT57JF99Ow0KCX07DQogICAgfTsN
CiAgICAjIFByb2Nlc3MgdGhlIG9wdGlvbnMuDQogICAgIyAoTm93IGluIHNv
cnRlZCBvcmRlciBmb3IgY29uc2lzdGVuY3kgcmVnYXJsZXNzIG9mIGhhc2gg
b3JkZXJpbmcuKQ0KICAgIG15KCRvcHRpb25zKSA9ICcnOw0KICAgIGZvcmVh
Y2ggKHNvcnQga2V5cyAlJG9wdGlvbnNfcmVmKSB7DQoJIyBwcmludGYgU1RE
RVJSICJvcHRpb246ICRfIGlzICIgLiAkb3B0aW9uc19yZWYtPnskX30gLiAi
XG4iOw0KCW5leHQgaWYgKGdlbmVyaWNfb3B0aW9uKCRfKSk7DQoJJG9wdGlv
bnMgLj0gJF8gLiAnPScgLiAkb3B0aW9uc19yZWYtPnskX30gLiAnJic7DQog
ICAgfTsNCiAgICAkc2VsZi0+e19kZWJ1Z30gPSAkb3B0aW9uc19yZWYtPnsn
c2VhcmNoX2RlYnVnJ307DQogICAgJHNlbGYtPntfZGVidWd9ID0gMiBpZiAo
JG9wdGlvbnNfcmVmLT57J3NlYXJjaF9wYXJzZV9kZWJ1Zyd9KTsNCiAgICAk
c2VsZi0+e19kZWJ1Z30gPSAwIGlmICghZGVmaW5lZCgkc2VsZi0+e19kZWJ1
Z30pKTsNCiAgICANCiAgICAjIEZpbmFsbHkgZmlndXJlIG91dCB0aGUgdXJs
Lg0KICAgICRzZWxmLT57X2Jhc2VfdXJsfSA9IA0KCSRzZWxmLT57X25leHRf
dXJsfSA9DQoJJHNlbGYtPntfb3B0aW9uc317J3NlYXJjaF91cmwnfSAuDQoJ
Ij8iIC4gJG9wdGlvbnMgLg0KCSJxPSIgLiAkbmF0aXZlX3F1ZXJ5Ow0KICAg
IHByaW50IFNUREVSUiAkc2VsZi0+e19iYXNlX3VybH0gLiAiXG4iIGlmICgk
c2VsZi0+e19kZWJ1Z30pOw0KfQ0KDQojIHByaXZhdGUNCnN1YiBzYXZlX29s
ZF9oaXQgew0KICAgIG15KCRzZWxmKSA9IHNoaWZ0Ow0KICAgIG15KCRvbGRf
aGl0KSA9IHNoaWZ0Ow0KICAgIG15KCRvbGRfcmF3KSA9IHNoaWZ0Ow0KDQog
ICAgaWYgKGRlZmluZWQoJG9sZF9oaXQpKSB7DQoJJG9sZF9oaXQtPnJhdygk
b2xkX3JhdykgaWYgKGRlZmluZWQoJG9sZF9yYXcpKTsNCglwdXNoKEB7JHNl
bGYtPntjYWNoZX19LCAkb2xkX2hpdCk7DQogICAgfTsNCg0KICAgIHJldHVy
bih1bmRlZiwgdW5kZWYpOw0KfQ0KDQojIHByaXZhdGUNCnN1YiBiZWdpbl9u
ZXdfaGl0DQp7DQogICAgbXkoJHNlbGYpID0gc2hpZnQ7DQogICAgbXkoJG9s
ZF9oaXQpID0gc2hpZnQ7DQogICAgbXkoJG9sZF9yYXcpID0gc2hpZnQ7DQoN
CiAgICAkc2VsZi0+c2F2ZV9vbGRfaGl0KCRvbGRfaGl0LCAkb2xkX3Jhdyk7
DQoNCiAgICAjIE1ha2UgYSBuZXcgaGl0Lg0KICAgIHJldHVybiAobmV3IFdX
Vzo6U2VhcmNoUmVzdWx0LCAnJyk7DQp9DQoNCg0KIyBwcml2YXRlDQpzdWIg
bmF0aXZlX3JldHJpZXZlX3NvbWUNCnsNCiAgICBteSAoJHNlbGYpID0gQF87
DQoNCiAgICAjIGZhc3QgZXhpdCBpZiBhbHJlYWR5IGRvbmUNCiAgICByZXR1
cm4gdW5kZWYgaWYgKCFkZWZpbmVkKCRzZWxmLT57X25leHRfdXJsfSkpOw0K
DQogICAgIyBnZXQgc29tZQ0KICAgIHByaW50IFNUREVSUiAiV1dXOjpTZWFy
Y2g6OkFsdGFWaXN0YU5MOjpuYXRpdmVfcmV0cmlldmVfc29tZTogZmV0Y2hp
bmcgIiAuICRzZWxmLT57X25leHRfdXJsfSAuICJcbiIgaWYgKCRzZWxmLT57
X2RlYnVnfSk7DQogICAgbXkoJHJlc3BvbnNlKSA9ICRzZWxmLT5odHRwX3Jl
cXVlc3QoJ0dFVCcsICRzZWxmLT57X25leHRfdXJsfSk7DQogICAgJHNlbGYt
PntyZXNwb25zZX0gPSAkcmVzcG9uc2U7DQogICAgaWYgKCEkcmVzcG9uc2Ut
PmlzX3N1Y2Nlc3MpIHsNCglyZXR1cm4gdW5kZWY7DQogICAgfTsNCg0KIyBw
YXJzZSB0aGUgb3V0cHV0DQogICAgbXkoJEhFQURFUiwgJEhJVFMsICRJTkhJ
VCwgJFRSQUlMRVIsICRQT1NUX05FWFQpID0gKDEuLjEwKTsgICMgb3JkZXIg
bWF0dGVycw0KICAgIG15KCRoaXRzX2ZvdW5kKSA9IDA7DQogICAgbXkoJHN0
YXRlKSA9ICgkSEVBREVSKTsNCiAgICBteSgkaGl0KSA9IHVuZGVmOw0KICAg
IG15KCRyYXcpID0gJyc7DQogICAgZm9yZWFjaCAoJHNlbGYtPnNwbGl0X2xp
bmVzKCRyZXNwb25zZS0+Y29udGVudCgpKSkgew0KICAgICAgICBuZXh0IGlm
IG1AXiRAOyAjIHNob3J0IGNpcmN1aXQgZm9yIGJsYW5rIGxpbmVzDQoJIyMj
IyMjDQoJIyBIRUFERVIgUEFSU0lORzogZmluZCB0aGUgbnVtYmVyIG9mIGhp
dHMNCgkjDQoJaWYgKDApIHsNCgl9IGVsc2lmICgkc3RhdGUgPT0gJEhFQURF
UiAmJiAvQWx0YVZpc3RhIHZvbmQgZ2VlbiBkb2N1bWVudGVuIHZvb3IgdXcg
em9la2Jld2Vya2luZy9pKSB7DQoJICAgICMgMjUtT2N0LTk5DQoJICAgICRz
ZWxmLT5hcHByb3hpbWF0ZV9yZXN1bHRfY291bnQoMCk7DQoJICAgICRzdGF0
ZSA9ICRUUkFJTEVSOw0KCSAgICBwcmludCBTVERFUlIgIlBBUlNFKDEwOkhF
QURFUi0+SElUUyk6IG5vIGRvY3VtZW50cyBmb3VuZC5cbiIgaWYgKCRzZWxm
LT57X2RlYnVnfSA+PSAyKTsNCiAgICAgICAgIyMjIyMjDQoJfSBlbHNpZiAo
JHN0YXRlID09ICRIRUFERVIgJiYgLyhbXGQsXSspIGdldm9uZGVuPyBwYWdp
bmEncy9pKSB7DQoJICAgICMgMjUtT2N0LTk5DQoJICAgIG15KCRuKSA9ICQx
Ow0KCSAgICAkbiA9fiBzLywvL2c7DQoJICAgICRzZWxmLT5hcHByb3hpbWF0
ZV9yZXN1bHRfY291bnQoJG4pOw0KCSAgICAkc3RhdGUgPSAkSElUUzsNCgkg
ICAgcHJpbnQgU1RERVJSICJQQVJTRSgxMDpIRUFERVItPkhJVFMpOiAkbiBk
b2N1bWVudHMgZm91bmQuXG4iIGlmICgkc2VsZi0+e19kZWJ1Z30gPj0gMik7
DQoJIyMjIyMjDQoJIyBISVRTIFBBUlNJTkc6IGZpbmQgZWFjaCBoaXQNCgkj
DQoJfSBlbHNpZiAoJHN0YXRlID09ICRISVRTICYmIC8oPHRhYmxlIHdpZHRo
PSIxMDAlIiBhbGlnbj0iY2VudGVyIj4pL2kpIHsNCiRzdGF0ZSA9ICRUUkFJ
TEVSOw0KCSAgICBwcmludCBTVERFUlIgIlBBUlNFKDExOkhJVFMtPlRSQUlM
RVIpOiBkb25lLlxuIiBpZiAoJHNlbGYtPntfZGVidWd9ID49IDIpOw0KDQoJ
fSBlbHNpZiAoJHN0YXRlID09ICRISVRTICYmIC88ZGw+PGR0Pi9pKSB7DQoJ
ICAgICMgMjUtT2N0LTk5DQoJICAgICgkaGl0LCAkcmF3KSA9ICRzZWxmLT5i
ZWdpbl9uZXdfaGl0KCRoaXQsICRyYXcpOw0KCSAgICAkaGl0c19mb3VuZCsr
Ow0KCSAgICAkcmF3IC49ICRfOw0KCSAgICAkc3RhdGUgPSAkSU5ISVQ7DQoJ
ICAgIHByaW50IFNUREVSUiAiUEFSU0UoMTI6SElUUy0+SU5ISVQpOiBoaXQg
c3RhcnQuXG4iIGlmICgkc2VsZi0+e19kZWJ1Z30gPj0gMik7DQoNCgl9IGVs
c2lmICgkc3RhdGUgPT0gJElOSElUICYmIC9ePGI+VVJMOiA8XC9iPjxGT05U
IGNvbG9yPSIjNzc3Nzc3Ij4oW14iXSspPGJyPi9pKSB7ICMiDQoJICAgICMg
MjUtT2N0LTk5DQoJICAgICRyYXcgLj0gJF87DQoJICAgICRoaXQtPmFkZF91
cmwoJDEpOw0KCSAgICBwcmludCBTVERFUlIgIlBBUlNFKDEzOklOSElUKTog
dXJsOiAkMS5cbiIgaWYgKCRzZWxmLT57X2RlYnVnfSA+PSAyKTsNCg0KCX0g
ZWxzaWYgKCRzdGF0ZSA9PSAkSU5ISVQgJiYgL148YS4qSFJFRi4qPiguKyk8
XC9hPi4qPFwvZHQ+L2kpIHsNCgkgICAgIyAyNS1PY3QtOTkNCgkgICAgJHJh
dyAuPSAkXzsNCgkgICAgbXkoJHRpdGxlKSA9ICQxOw0KCSAgICAjICR0aXRs
ZSA9fiBzLzxcLz9lbT4vL2lnOyAgIyBzdHJpcCBrZXl3b3JkIGVtcGhhc2lz
ICh1c2UgcmF3IGlmIHlvdSB3YW50IHRvIGdldCBpdCBiYWNLKQ0KCSAgICAk
aGl0LT50aXRsZSgkdGl0bGUpOw0KCSAgICBwcmludCBTVERFUlIgIlBBUlNF
KDEzOklOSElUKTogdGl0bGU6ICQxLlxuIiBpZiAoJHNlbGYtPntfZGVidWd9
ID49IDIpOw0KDQoJfSBlbHNpZiAoJHN0YXRlID09ICRJTkhJVCAmJiAvXjxk
ZD4oLiopPGJyPi9pKSB7DQoJICAgICMgMjUtT2N0LTk5DQoJICAgICRyYXcg
Lj0gJF87DQoJICAgICRoaXQtPmRlc2NyaXB0aW9uKCQxKTsNCgkgICAgcHJp
bnQgU1RERVJSICJQQVJTRSgxMzpJTkhJVCk6IGRlc2NyaXB0aW9uLlxuIiBp
ZiAoJHNlbGYtPntfZGVidWd9ID49IDIpOw0KDQoJfSBlbHNpZiAoJHN0YXRl
ID09ICRJTkhJVCAmJiAvXkxhYXRzdGUgd2lqemlnaW5nOiAoLiopJC9pKSB7
DQoJICAgICMgMjUtT2N0LTk5DQoJICAgICRyYXcgLj0gJF87DQoJICAgICRo
aXQtPmNoYW5nZV9kYXRlKCQxKTsNCgkgICAgcHJpbnQgU1RERVJSICJQQVJT
RSgxMzpJTkhJVCk6IG1vZCBkYXRlLlxuIiBpZiAoJHNlbGYtPntfZGVidWd9
ID49IDIpOw0KDQoJfSBlbHNpZiAoJHN0YXRlID09ICRJTkhJVCAmJiAvXjxc
L2RsPi9pKSB7DQoJICAgICMgMjUtT2N0LTk5DQoJICAgICRyYXcgLj0gJF87
DQoJICAgICgkaGl0LCAkcmF3KSA9ICRzZWxmLT5zYXZlX29sZF9oaXQoJGhp
dCwgJHJhdyk7DQoJICAgICRzdGF0ZSA9ICRISVRTOw0KCSAgICBwcmludCBT
VERFUlIgIlBBUlNFKDEzOklOSElULT5ISVRTKTogZW5kIGhpdC5cbiIgaWYg
KCRzZWxmLT57X2RlYnVnfSA+PSAyKTsNCg0KCX0gZWxzaWYgKCRzdGF0ZSA9
PSAkSU5ISVQpIHsNCgkgICAgIyBvdGhlciByYW5kb20gc3R1ZmYgaW4gYSBo
aXQtLS1hY2N1bXVsYXRlIGl0DQoJICAgICRyYXcgLj0gJF87DQoJICAgIHBy
aW50IFNUREVSUiAiUEFSU0UoMTQ6SU5ISVQpOiBubyBtYXRjaC5cbiIgaWYg
KCRzZWxmLT57X2RlYnVnfSA+PSAyKTsNCiAgICAgICAgICAgIHByaW50IFNU
REVSUiAnICd4IDEyLCAiJF9cbiIgaWYgKCRzZWxmLT57X2RlYnVnfSA+PSAz
KTsNCg0KCX0gZWxzaWYgKCRoaXRzX2ZvdW5kICYmICgkc3RhdGUgPT0gJFRS
QUlMRVIgfHwgJHN0YXRlID09ICRISVRTKSAmJiAvPGFbXj5dK2hyZWY9Iihb
XiJdKykiLipcJmd0O1wmZ3Q7L2kpIHsgIyAiDQoJICAgICMgKGFib3ZlLCBu
b3RlIHRoZSB0cmljayAkaGl0c19mb3VuZCBzbyB3ZSBkb24ndCBwcmVtYXR1
cmVseSB0ZXJtaW5hdGUuKQ0KCSAgICAjIHNldCB1cCBuZXh0IHBhZ2UNCgkg
ICAgbXkoJHJlbGF0aXZlX3VybCkgPSAkMTsNCgkgICAgIyBoYWNrOiAgbWFr
ZSBzdXJlIGZtdD1kIHN0YXlzIG9uIG5ld3MgVVJMcw0KCSAgICAkcmVsYXRp
dmVfdXJsID1+IHMvd2hhdD1uZXdzL3doYXQ9bmV3c1wmZm10PWQvIGlmICgk
cmVsYXRpdmVfdXJsICF+IC9mbXQ9ZC9pKTsNCiAgICAgICAgICAgIG15KCRu
KSA9IG5ldyBVUkk6OlVSTCgkcmVsYXRpdmVfdXJsLCAkc2VsZi0+e19iYXNl
X3VybH0pOw0KICAgICAgICAgICAgJG4gPSAkbi0+YWJzOw0KICAgICAgICAg
ICAgJHNlbGYtPntfbmV4dF91cmx9ID0gJG47CSAgICAkc3RhdGUgPSAkUE9T
VF9ORVhUOw0KCSAgICBwcmludCBTVERFUlIgIlBBUlNFKDE1Oi0+UE9TVF9O
RVhUKTogZm91bmQgbmV4dCwgJG4uXG4iIGlmICgkc2VsZi0+e19kZWJ1Z30g
Pj0gMik7DQoNCgl9IGVsc2Ugew0KCSAgICAjIGFjY3VtdWxhdGUgcmF3DQoJ
ICAgICRyYXcgLj0gJF87DQoJICAgIHByaW50IFNUREVSUiAiUEFSU0UoUkFX
KTogJF9cbiIgaWYgKCRzZWxmLT57X2RlYnVnfSA+PSAzKTsNCgl9Ow0KICAg
IH07DQogICAgaWYgKCRzdGF0ZSAhPSAkUE9TVF9ORVhUKSB7DQoJIyBlbmQs
IG5vIG90aGVyIHBhZ2VzIChtaXNzZWQgYGBuZXh0JycgdGFnKQ0KCWlmICgk
c3RhdGUgPT0gJEhJVFMpIHsNCgkgICAgJHNlbGYtPmJlZ2luX25ld19oaXQo
JGhpdCwgJHJhdyk7ICAgIyBzYXZlIG9sZCBvbmUNCgkgICAgcHJpbnQgU1RE
RVJSICJQQVJTRTogbmV2ZXIgZ290IHRvIFRSQUlMRVIuXG4iIGlmICgkc2Vs
Zi0+e19kZWJ1Z30gPj0gMik7DQoJfTsNCgkkc2VsZi0+e19uZXh0X3VybH0g
PSB1bmRlZjsNCiAgICB9Ow0KDQogICAgIyBzbGVlcCBzbyBhcyB0byBub3Qg
b3ZlcmxvYWQgYWx0YXZpc3RhDQogICAgJHNlbGYtPnVzZXJfYWdlbnRfZGVs
YXkgaWYgKGRlZmluZWQoJHNlbGYtPntfbmV4dF91cmx9KSk7DQoNCiAgICBy
ZXR1cm4gJGhpdHNfZm91bmQ7DQp9DQoNCjE7DQo=
--8323328-1224416301-984674016=:23502--

