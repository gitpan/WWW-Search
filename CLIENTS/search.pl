#!/home/johnh/BIN/perl5 -w

#
# search.pl
# Copyright (C) 1996 by USC/ISI
# $Id: search.pl,v 1.6 1996/10/10 18:11:58 johnh Exp $
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


sub usage {
    print STDERR <<END;
usage: $0 query

Make a query to Alta Vista, showing the primary URLs which match.
END
    exit 1;
}

=head1 NAME

search.pl - a web-searching application demonstrating WWW::Search


=head1 DESCRIPTION

This program is provides a command-line interface to web search engines,
listing all URLs found for a given query.  This program also provides
a simple demonstration of the WWW::Search Perl library for web searches.

Currently the program does searches on AltaVista 
F<http://www.altavista.digital.com>.
We plan to expand WWW::Search to support other search engines 
in late 1996.

We plan to provide more sophisticated services using WWW::Search.
One service is an periodic service where we automatically search
the web for relevant documents.  A prototype of this system 
(not yet using WWW::Search) is available at
F<http://www.isi.edu/lsam/tools/index.html>
with sample output at
F<http://www.isi.edu/div7/ib/jog/index.html>.


=head1 SEE ALSO

For the library, see L<WWW::Search>.


=cut

use strict;

&usage if ($#ARGV == -1);
&usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');

BEGIN {
    # next line is a development hack
    push (@INC, "..");
}
use WWW::Search;
use WWW::Search::AltaVista;

&main(join(" ", @ARGV));
exit 0;


sub main {
    my($query) = @_;
    my($search) = new WWW::Search::AltaVista;
    $search->native_query(WWW::Search::escape_query($query));
    my($result);
#    foreach $result ($search->results()) {
 #	print $result->url, "\n";
 #    };
     while ($result = $search->next_result()) {
	 print $result->url, "\n";
    };
};
