#!/usr/local/bin/perl -w

#
# Back-end for Infoseek search engine (Usenet news)
# Cesare Feroldi de Rosa, <C.Feroldi@IT.net> 1996
# derived from:
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: News.pm,v 1.5 1996/12/02 22:16:38 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Infoseek::News;

=head1 NAME

WWW::Search::Infoseek::News - class for searching for News at Infoseek

=head1 DESCRIPTION

Back-end for Infoseek search engine (Usenet news).

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 OPTIONS

=over 8

=item operator
Ex. operator=>'AND'
Values AND or OR (defaults to OR).

If you want to use directly the native '+' and '-' operators than
use the OR operator.

=item groups
Ex. groups=>'comp.foo.bar'
Defaults to all groups.


=back

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 AUTHOR

Cesare Feroldi de Rosa, <C.Feroldi@IT.net> 1996.
(Derived from AltaVista.pm.)



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
# ./search.pl xxxasdf                        --- no hits
# ./search.pl '"lsam replication"'           --- single page return
# ./search.pl '+"john heidemann" +work'      --- 9 page return
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
# $VERSION = 1.000;
@ISA = qw(WWW::Search::Infoseek Exporter);

use WWW::Search::Infoseek;
use Carp ();
require WWW::SearchResult;



# private
sub native_setup_search
{
	my($self)=shift;
	my($native_query, $native_options_ref) = @_;
	if (!defined($self->{_default_options})) {
		$self->{_default_options} = {
 	 				operator	=>	'OR',
 	 				col	=>	'NN',
 	 				lk	=>	'noframes',
 	 				sv	=>	'IS'
 				};
	}
	if (defined $native_options_ref->{'group'}) {
		$native_options_ref->{'col'}= 'NN%2Ccat_' . $native_options_ref->{'group'}
			if $native_options_ref->{'group'} ne '';
	delete $native_options_ref->{'group'};
	}
	return $self->SUPER::native_setup_search(@_);
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
    my($NextPage,$List,$Article)=(0..0);
    my($raw);
    for (split(/\n/, $response->content())) {
		next if /^$/;
		if (m#: No Results</title>#) {
			$self->{_next_url} = undef;
			return undef;
		} elsif (m#<b>Results</b>\s+[1-9]\d*\s+-\s+[1-9]\d*\s+of\s+([1-9]\d*)#) {
			unless ($List) {
				$self->approximate_result_count($1);
				$List++;
			}	else {
				$self->{_next_url}= undef unless $NextPage;
				$self->user_agent_delay if (defined($self->{_next_url}));
				return $hits_found;            
			}
		} elsif (m# <a href="(http://guide-p.infoseek.com/Titles?[^"]+)">next&nbsp;\d+</a>#) {
			$NextPage=$self->{_next_url}=$1;
		} elsif (m#<b><a href="(http://guide-p\.infoseek\.com/DB\?.+&arn=[^"]+)">([^<]+)</a></b> <br>#) {
		    $hit = new WWW::SearchResult;
		    $hit->add_url($1);
		    $hits_found++;
		    $hit->title($2);	    
		    $Article++;
		    $raw=$_;
		} elsif ($Article) {
			if (m#^([^<>]+)&nbsp;$#) {
				$hit->description($1)
			} elsif (m#<a href="(http://guide-p.infoseek.com/[^"]+)">([^<]+)</a>#) {
				$hit->add_related_url($1);
    	 			$hit->add_related_title($2);
			} elsif (s#<font size="-1">#<H5>#) {
			} elsif (m#<b>\s*([1-9]\d*%)</b> &nbsp; &nbsp; &nbsp; &nbsp#) {
				$hit->score($1);
			} elsif (m#([A-Z][a-z]{2} [A-Z][a-z]{2}\s+[1-9]\d?\s+(\d{2}:){2}\d{2} [1-2]\d{3}) &nbsp; &nbsp; \((Lines: \d+)\)#) {
				$hit->change_date($1);
				$hit->size($3);
			} elsif (s#</font>#</H5>#) {
				$raw.=$_;
				$Article--;
				$hit->raw($raw);
				push(@{$self->{cache}}, $hit);
				next;
			}
	    	$raw.=$_;
		} 	    
	};


}

1;
