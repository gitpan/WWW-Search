use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
	if ($Config{'osname'} eq 'VMS' or
	    $Config{'osname'} eq 'OS2');  # "case-forgiving"
open OUT,">$file" or die "Can't create $file: $!";
chmod(0755, $file);
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'} -w
    eval 'exec perl -S \$0 "\$@"'
	if 0;

!GROK!THIS!

print OUT <<'!NO!SUBS!';

#
# search.pl
# Copyright (C) 1996 by USC/ISI
# $Id: search.PL,v 1.7 1996/10/29 21:09:39 johnh Exp $
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

!NO!SUBS!
