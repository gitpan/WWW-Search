#!/usr/local/bin/perl -w

#
# Web.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: Web.pm,v 1.1 1999/06/18 19:16:18 mthurn Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::AltaVista::Web;

=head1 NAME

WWW::Search::AltaVista::Web - class for Alta Vista web searching


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('AltaVista::Web');


=head1 DESCRIPTION

This class implements the AltaVista web search
(specializing AltaVista and WWW::Search).
It handles making and interpreting AltaVista web searches
F<http://www.altavista.com>.

Details of AltaVista can be found at L<WWW::Search::AltaVista>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 AUTHOR

C<WWW::Search> is written by John Heidemann, <johnh@isi.edu>.


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
@ISA = qw(WWW::Search::AltaVista Exporter);
use WWW::Search::AltaVista;

# private
sub native_setup_search
{
    my($self) = shift;
    if (!defined($self->{_options})) {
	$self->{_options} = {
	    pg => 'q',
	    'text' => 'yes',
	    what => 'web',
	    fmt => 'd',
	    'search_url' => 'http://www.altavista.com/cgi-bin/query',
        };
    };
    # let AltaVista.pm finish up the hard work.
    return $self->SUPER::native_setup_search(@_);
}

1;
