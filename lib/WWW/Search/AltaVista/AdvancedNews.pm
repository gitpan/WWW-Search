#!/usr/local/bin/perl -w

#
# AdvancedNews.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: AdvancedNews.pm,v 1.7 1998/05/28 04:05:48 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::AltaVista::AdvancedNews;

=head1 NAME

WWW::Search::AltaVista::AdvancedNews - class for advanced Alta Vista news searching


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('AltaVista::AdvancedNews');


=head1 DESCRIPTION

This class implements the advanced AltaVista news search
(specializing AltaVista and WWW::Search).
It handles making and interpreting AltaVista web searches
F<http://www.altavista.digital.com>.

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
	    pg => 'aq',
	    'text' => 'yes',
	    what => 'news',
	    fmt => 'd',
	    'search_url' => 'http://www.altavista.digital.com/cgi-bin/query',
        };
    };
    # let AltaVista.pm finish up the hard work.
    return $self->SUPER::native_setup_search(@_);
}

1;
