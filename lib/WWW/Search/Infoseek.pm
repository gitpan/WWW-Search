#!/usr/local/bin/perl -w

# Back-end for Infoseek search engine
# Cesare Feroldi de Rosa <C.Feroldi@IT.net> 1996
# derived from:
# AltaVista.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Infoseek.pm,v 1.4 1997/01/08 20:03:27 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::Infoseek;

=head1 NAME

WWW::Search::Infoseek - class for searching Infoseek.

=head1 DESCRIPTION

This class is an Infoseek specialization of WWW::Search.
It handles making and interpreting AltaVista searches
F<http://www.infoseek.com>.

This is an abstract class: you cannot instance a variable of this type.

Descendant classes must override the native_retrieve_some method.

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
@ISA = qw(WWW::Search Exporter);

use Carp ();
require WWW::SearchResult;



# private
sub native_setup_search
{
	my($self, $native_query, $native_options_ref) = @_;
	# Infoseek returns some kind of bogus data for
	# robots.txt, so we are a user.   -johnh, 25-Nov-96
	$self->{user_agent} = $self->user_agent('user');
	$self->{_next_to_retrieve} = 0;
	$self->{_host}='http://www.infoseek.com';
	if ($native_query=~m#^http://#) {
	     $self->{_base_url} = $self->{_next_url} = $native_query;
	     return;
	 }
	if (defined($native_options_ref)) {
		foreach (keys %$native_options_ref) {
			$self->{_default_options}->{$_} = $native_options_ref->{$_}
		}
	}
	if ($self->{_default_options}->{'operator'} eq 'AND') {
		 $native_query=~s/\+/\+%2B/g;
		 $native_query='%2B' . $native_query;
	}
	delete $self->{_default_options}->{'operator'};
	my($options) = '';
	foreach (keys %{$self->{_default_options}}) {
		$options .= $_ . '=' . $self->{_default_options}->{$_} . '&';
	}
	$self->{_base_url} = $self->{_next_url} =
		'http://guide-p.infoseek.com/Titles?' .
		$options . 'qt=' . $native_query ;
	# print "DEBUG base_url: $self->{_base_url}\n";
}


# private
sub native_retrieve_some {
	Carp::croak ("WWW::Search::Infoseek is an abstract class\nApplications should use Infoseek::Web or other back-ends directly;\nback-ends must override this method.\n");
}

1;
