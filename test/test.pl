#!/home/johnh/BIN/perl5 -w

#
# test.pl
# Copyright (C) 1997 by USC/ISI
# $Id: test.pl,v 1.4 1997/10/08 23:02:38 johnh Exp $
#
# Copyright (c) 1997 University of Southern California.
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
usage: $0

Runs WWW::Search tests.
END
    exit 1;
}

use strict;

use Config;
use Getopt::Long;
&usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');
my(%opts);
&GetOptions(\%opts, qw(v));
# &usage if ($#ARGV < 0);


my($verbose) = $opts{v};
my($fullperl);
my($file, $query, $date, $search_engine, $pwd, $internal, $maintainer);

sub test {
    print "trial $file ($search_engine)\n";
    my($src) = $internal ? "-o search_from_file=$file" : "";
    my($cmd) = "$fullperl -I$pwd/lib $pwd/bin/WebSearch -e $search_engine $src -- '$query'";
    print "\t$cmd\n" if ($verbose);
    open(TRIALSTREAM, "$cmd|") || die "$0: cannot run test\n";
    open(TRIALFILE, ">$file.trial") || die "$0: cannot open $file.trial\n";
    while (<TRIALSTREAM>) {
	print TRIALFILE $_;
    };
    close TRIALSTREAM;
    close TRIALFILE;
    if (-f "$file.out") {
	system("diff -c $file.out $file.trial >$file.diff");
	my($e) = ($? >> 8);
	if ($e == 0) {
	    print "\tok.\n";
	} elsif ($e == 1) {
	    print "\tDIFFERENCE DETECTED.\n";
	} else {
	    print "\tDIFF ERROR.\n";
	};
    } else {
	print "\tno saved output.\n";
    };
    print "\n";
};

sub no_test {
    print "trial none ($search_engine)\n";
    print "\tThis search engine doesn't have any tests,\n";
    print "\tbut report problems for it to\n\t$maintainer.\n";
    print "\n";
}

sub not_working {
    print "trial none ($search_engine)\n";
    print "\tThis search engine is known to be non-functional.  You are encouraged\n";
    print "\tto investigate the problem or send mail to its maintainer\n\t$maintainer.\n";
    print "\n";
}

sub not_working_and_abandonded {
    print "trial none ($search_engine)\n";
    print "\tThis search engine is known to be non-functional.  You are encouraged\n";
    print "\tto adopt it from it's original author\n\t$maintainer.\n";
    print "\n";
}

sub test_cases {
    ######################################################################
    $search_engine = 'AltaVista';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/zero_result';
    $query = '+LSAM +NoSuchWord';
    $date = 'Fri Oct  3 16:30:25 PDT 1997';
    test;

    $file = 'test/AltaVista/one_page_result';
    $query = '+LSAM +AutoSearch';
    test;

    $file = 'test/AltaVista/two_page_result';
    $query = '+LSAM +ISI +work';
    test;

    ######################################################################
    $search_engine = 'DejaNews';
    $maintainer = 'Cesare Feroldi de Rosa, <C.Feroldi@IT.net>';
    not_working;

    ######################################################################
    $search_engine = 'Excite';
    $maintainer = 'GLen Pringle <pringle@cs.monash.edu.au>';
    not_working;

#    $search_engine = 'Gopher';
#    $maintainer = 'Paul Lindner <lindner@reliefweb.int>';
#    not_working;

    ######################################################################
    $search_engine = 'HotBot';
    $maintainer = 'Wm. L. Scheding <wls@isi.edu>';
    not_working_and_abandonded;

    ######################################################################
    $search_engine = 'Infoseek';
    $maintainer = 'Cesare Feroldi de Rosa, <C.Feroldi@IT.net>';
    not_working;

    ######################################################################
    $search_engine = 'Lycos';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/Lycos/zero_result';
    $query = 'LSAM NoSuchWord';
    test;

    $file = 'test/Lycos/one_page_result';
    $query = 'LSAM IB ISI';
    test;

    $file = 'test/Lycos/two_page_result';
    $query = 'LSAM ISI';
    test;

    ######################################################################
    $search_engine = 'PLweb';
    $maintainer = 'Paul Lindner <lindner@reliefweb.int>';
    not_working;

    ######################################################################
    $search_engine = 'SFgate';
    $maintainer = 'Paul Lindner <lindner@reliefweb.int>';
    not_working;

#    $search_engine = 'Simple';
#    $maintainer = 'Paul Lindner <lindner@reliefweb.int>';
#    not_working;

    ######################################################################
    $search_engine = 'Verity';
    $maintainer = 'Paul Lindner <lindner@reliefweb.int>';
    not_working;

    ######################################################################
    $search_engine = 'Yahoo';
    $maintainer = 'Wm. L. Scheding <wls@isi.edu>';
    not_working;
}

sub main {
    $pwd = `pwd`;
    chomp($pwd);

    $fullperl = $Config{'perlpath'};

    print "\n\nTESTING INTERNAL PARSING.\n\t(Errors here should be reported to the WWW::Search maintainer.)\n\n";
    $internal = 1;    
    &test_cases;

    print "\n\nTESTING EXTERNAL QUERIES.\n\t(Errors here suggest search-engine remormatting and should be\n\treported to the maintainer of the back-end for the search engine.)\n\n";
    $internal = 0;
    &test_cases;
}

main;

exit 0;

