#!/usr/local/bin/perl -w

#
# Back-end for Dejanews search engine (Usenet news)
# Cesare Feroldi de Rosa, <C.Feroldi@IT.net> 1996
# derived from:
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Dejanews.pm,v 1.7 1996/11/25 19:55:14 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Dejanews;

=head1 NAME

WWW::Search::Dejanews - Perl class for searching Dejanews

=head1 DESCRIPTION

This class is a C<WWW::Search> 
back-end for the Dejanews search engine for Usenet news.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 OPTIONS

=over 8

=item defaultOp
AND or OR (defaults to OR).

=item groups
Ex. comp.foo.bar.
Defaults to all groups.

=back

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 AUTHOR

Cesare Feroldi de Rosa, <C.Feroldi@IT.net>, 1996.
(Derived from AltaVista.pm.)


=head1 COPYRIGHT

This back-end was contributed to USC/ISI by Cesare Feroldi de Rosa.

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
# ./search.pl xxxasdf                        --- no hits
# ./search.pl '"lsam replication"'           --- single page return
# ./search.pl '+"john heidemann" +work'      --- 9 page return
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
    my($self, $native_query, $native_options_ref) = @_;
    if (!defined($self->{_default_options})) {
	$self->{_default_options} = {	    
            defaultOp => OR,
            groups    => ''
        };
    }
    if (defined($native_options_ref)) {
	foreach (keys %$native_options_ref) {
	    $self->{_default_options}->{$_} = $native_options_ref->{$_}
	};
    }
    my($options) = '';
    foreach (keys %{$self->{_default_options}}) {
        next if $self->{_default_options}->{$_} eq '';
	$options .= $_ . '=' . $self->{_default_options}->{$_} . '&';
    };	
    $self->user_agent();
    $self->{_next_to_retrieve} = 0;
    $self->{_base_url} = 
	$self->{_next_url} =
	'http://search.dejanews.com/dnquery.xp?' .
	$options . 'query=' . $native_query;
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
    #define constants:
    my($hits_found) = 0;
    my($hit) = ();
    my($NextUrl)=0;
    for (split(/\n/, $response->content())) {
	if ((m#^Hits <B>[1-9]\d*-[1-9]\d*</B> of ([1-9]\d*) for Query:#)
	    ||(m#^<B>([1-9]\d*)</B> Hits for Query:#))
	     {
	    $self->approximate_result_count($1);
	} elsif (m#Your query did not match any articles#) {
	    $self->{_next_url} = undef;
	    return undef;
	} elsif (m#^\s+[1-9]\d*\. ([09]\d/\d{2}/\d{2}) \d+ <A HREF="(http://[^.]+\.dejanews\.com/getdoc\.xp\?[^"]+)">([^<]+)</A> <B>([^< ]+)\s*</B> <A HREF="http://[^.]+\.dejanews\.com/profile\.xp\?[^"]+">([^<]+)</A>#i) {
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $hit = new WWW::SearchResult;
	    $hit->add_url($2);
	    $hits_found++;
	    $hit->title($3);
	    $hit->description(join(' ',($1,$4,$5)));
	} elsif (m#<A HREF="(http://[^.]+\.dejanews\.com/dnquery\.xp\?search=next&[^"]+)">Get next [1-9]\d* hits</A><HR>#) {
	    # more pages
	    $NextUrl=$self->{_next_url} = $1;	    
	} elsif (m#<P><B>Individual word hit counts</B>#) {
	    #end of page
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	     $self->{_next_url} = undef unless $NextUrl;
	     last;
	    } 	    
	};

    # sleep so as to not overload altavista
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
