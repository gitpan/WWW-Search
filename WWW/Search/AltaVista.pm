#!/usr/local/bin/perl -w

#
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: AltaVista.pm,v 1.7 1996/10/03 22:06:13 johnh Exp $
#
# Copyright (c) 1996 University of Southern California.
# All rights reserved.                                            
#                                                                
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation, advertising
# materials, and other materials related to such distribution and use
# acknowledge that the software was developed by the University of
# Southern California, Information Sciences Institute.  The name of the
# University may not be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 


package WWW::Search::AltaVista;

=head1 NAME

WWW::Search::AltaVista - class for searching Alta Vista 

=head1 DESCRIPTION

This class is an AltaVista specialization of WWW::Search.
It handles making and interpreting AltaVista searches
F<http://www.altavista.digital.com>.


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 METHODS AND FUNCTIONS

=cut


#
#  Test cases:
# ./search.pl xxxasdf                        --- no hits
# ./search.pl '"lsam replication"'           --- single page return
# ./search.pl '+"john heidemann" +work'      --- 9 page return
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
# $VERSION = 1.000;
require LWP::MemberMixin;
@ISA = qw(WWW::Search Exporter);

use Carp ();
require WWW::SearchResult;



# private
sub native_retrieve_some
{
    my ($self) = @_;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    my($request) = new HTTP::Request('GET', $self->{_next_url});
    my($response) = $self->{_user_agent}->request($request);
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    my($HEADER, $HITS, $TRAILER) = (1..10);
    my($hits_found) = 0;
    my($state) = ($HEADER);
    my($hit) = ();
    foreach (split(/\n/, $response->content())) {
	if ($state == $HEADER && /Documents?.*of\s*(about)?\s*(\d+)\s+matching/) {
	    $self->approximate_result_count($2);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^(<[Pp]>)?<dt><a href=\"([^"]+)"><strong>(.*)</strong></a><dd>(.*)\.<br>@) {
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $hit = new WWW::SearchResult;
	    $hit->add_url($2);
	    $hits_found++;
	    $hit->title($3);
	    $hit->description($4);
	} elsif ($state == $HITS && /^<cite><a href="([^"]+)">/) { #"
	    $hit->add_url($1);
	    $hits_found++;   # altavista counts URL==hit
	} elsif ($state == $HITS && /^<CENTER>.*\s+p\./) {
	    # end, with a list of other pages to go to
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    if (/Next\]/) {
		# set up next page
		my($relative_url) = m@<a\s+href="([^"]+)">\s*\[\s*[Nn]ext\s*\]\s*</a>@; #"
		$self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    } else {
		$self->{_next_url} = undef;
	    };
	    $state = $TRAILER;
	};
    };
    if ($state != $TRAILER) {
	# end, no other pages (missed ``next'' tag)
	if (defined($hit)) {
	    push(@{$self->{cache}}, $hit);
	};
	$self->{_next_url} = undef;
    };

    # sleep so as to not overload altavista
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

# private
sub native_setup_search
{
    my($self, $native_query) = @_;
    $self->{_user_agent} = WWW::Search::setup_user_agent;
    $self->{_next_to_retrieve} = 0;
    $self->{_base_url} = 
	$self->{_next_url} =
	"http://www.altavista.digital.com/cgi-bin/query?pg=q&what=web&fmt=d" .
	"&q=" . $native_query;
}


1;
