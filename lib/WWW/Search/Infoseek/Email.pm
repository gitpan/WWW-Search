#!/usr/local/bin/perl -w

# Back-end for Infoseek search engine
# Cesare Feroldi de Rosa, <C.Feroldi@IT.net> 1996
# derived from:
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Email.pm,v 1.1 1999/06/18 19:17:17 mthurn Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Infoseek::Email;

=head1 NAME

WWW::Search::Infoseek::Email - class for searching for e-mail at Infoseek

=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Infoseek::Email');

=head1 DESCRIPTION

Back-end for Infoseek search engine .

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 OPTIONS

=over 8

=item operator
Ex. operator=>'AND'
Values AND or OR (defaults to OR).

If you want to use directly the native '+' and '-' operators than
use the OR operator.



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

use Carp ();
use WWW::Search::Infoseek;
require WWW::SearchResult;



# private
sub native_setup_search
{
	my($self)=shift;
	if (!defined($self->{_default_options})) {
	 	 $self->{_default_options} = {
	 	 				operator	=>	'OR',
	 	 				lk	=>	'noframes',
	 	 				sv	=>	'IS',
	 	 				col	=>	'FO'
	 				};
	}	
	$self->{_host} = 'http://www.infoseek.com/';
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
    my($Article)=(0..0);
    my($raw);
    $self->{_next_url} = undef;
    for (split(/\n/, $response->content())) {
		next if /^$/;
		if (m#: No Results</title>#) {			
			return undef;
		} elsif	(m#<STRONG>Too Many Matches</STRONG><P>#) {
			return undef;
		} elsif (m#<STRONG>Successful Search, Found\s+(\d+)\s+Matches</STRONG><P>#) {			
			$self->approximate_result_count($1);
		} elsif (m#<a href="(/cgi-bin/Four11Main\?userdetail[^"]+)">([^<]+)</a>#) {
			$hit = new WWW::SearchResult;
			$hit->add_url($self->{_host} . $1);
			$hits_found++;
			$hit->title($2);	    
			$Article++;
			$raw=$_;
		} elsif ($Article) {
			if (m#^\s+(\@[^\s<]+)\s*#) {
				$hit->description($1)
			} elsif (m#^<br>$#) {	
				$Article--;
				$raw.=$_;
				$hit->raw($raw);
				push(@{$self->{cache}}, $hit);
				next;
			}
			$raw.=$_;
		}
    }


}

1;
