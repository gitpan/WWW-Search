#!/home/johnh/BIN/perl5 -w

#
# test.pl
# Copyright (C) 1997 by USC/ISI
# $Id: test.pl,v 1.10 1998/03/31 22:29:39 johnh Exp $
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
usage: $0 [-dIuv] [-e SearchEngine]

Runs WWW::Search tests.

Options:
    -e SearchEngine	limit actions to that search engine
    -u			update saved test files
    -v			verbose (show commands)
    -d			debug (don't actually run stuff)
    -I			run interal tests only


To save a result to a file, use the search_to_file option of WebSearch.
Something like:

bin/WebSearch -e AltaVista::Web -o search_to_file=test/AltaVista/Web/zero_result -- '+LSAM +No_SuchWord'
END
    # '
    exit 1;
}

use strict;

use Config;
use Getopt::Long;
&usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');
my(%opts);
&GetOptions(\%opts, qw(d e=s I u v));
# &usage if ($#ARGV < 0);


my($verbose) = $opts{'v'};
my($debug) = $opts{'d'};
my($desired_search_engine) = $opts{'e'};
my($update_saved_files) = $opts{'u'};
my($internal_only) = $opts{'I'};

my($fullperl);
my($file, $query, $date, $search_engine, $pwd, $maintainer);

my($MODE_DUMMY, $MODE_INTERNAL, $MODE_EXTERNAL, $MODE_UPDATE) = (0..10);

my($TEST_DUMMY, $TEST_EXACTLY, $TEST_BY_COUNTING, $TEST_GREATER_THAN, $TEST_RANGE) = (0..10);

sub relevant_test {
    return 1 if (!defined($desired_search_engine));
    return $desired_search_engine eq $search_engine;
}

sub web_search_bin {
    return "$fullperl -I$pwd/lib $pwd/bin/WebSearch ";
}

#
# Several test methods are possible:
# $TEST_EXACTLY:  output must match exactly (line for line, order)
# $TEST_BY_COUNTING:  test passes if number of lines is equal
# $TEST_GREATER_THAN:  test passes if we get more than N lines of output
# $TEST_RANGE:  like GREATER_THAN but contrained on both ends
#
sub test {
    my($mode) = shift @_;
    my($test_method) = shift @_;
    # print "mode=$mode, method=$test_method\n";

    return if (!relevant_test);

    print "trial $file ($search_engine)\n";
    my(@src);
    my(@output) = ();
    $src[$MODE_INTERNAL] = "-o search_from_file=$file";
    $src[$MODE_EXTERNAL] = "";
    $src[$MODE_UPDATE] = "-o search_to_file=$file";
    my($cmd) = &web_search_bin . "-e $search_engine $src[$mode] -- '$query'";
    $cmd = "$cmd | wc -l | sed 's/ //g'" if ($test_method == $TEST_BY_COUNTING && $mode != $MODE_UPDATE);
    print "\t$cmd\n" if ($verbose);
    open(TRIALSTREAM, "$cmd|") || die "$0: cannot run test\n";
    open(TRIALFILE, ">$file.trial") || die "$0: cannot open $file.trial\n";
    open(OUTFILE, ">$file.out") || die "$0: cannot open $file.out\n"
	if ($mode == $MODE_UPDATE);
    while (<TRIALSTREAM>) {
	print TRIALFILE $_;
	print OUTFILE $_ if ($mode == $MODE_UPDATE);
	push(@output, $_);
    };
    close TRIALSTREAM;
    close TRIALFILE;
    close OUTFILE if ($mode == $MODE_UPDATE);
    if (-f "$file.out") {
        my($e);
	if ($test_method == $TEST_GREATER_THAN) {
	    my($at_least_count) = @_;
	    $e = ($#output+1 >= $at_least_count) ? 0 : 1;
	} elsif ($test_method == $TEST_RANGE) {
	    my($low_end, $high_end) = @_;
	    $e = ($#output+1 >= $low_end && $#output+1 <= $high_end) ? 0 : 1;
	} else {
	    system("diff -c $file.out $file.trial >$file.diff");
	    $e = ($? >> 8);
	};
	if ($e == 0) {
	    print "\tok.\n";
	    unlink("$file.trial");   # clean up
	    unlink("$file.diff");   # clean up
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
    return if (!relevant_test);
    print "trial none ($search_engine)\n";
    print "\tThis search engine doesn't have any tests,\n";
    print "\tbut report problems for it to\n\t$maintainer.\n";
    print "\n";
}

sub not_working {
    return if (!relevant_test);
    print "trial none ($search_engine)\n";
    print "\tThis search engine is known to be non-functional.  You are encouraged\n";
    print "\tto investigate the problem or send mail to its maintainer\n\t$maintainer.\n";
    print "\n";
}

sub not_working_and_abandonded {
    return if (!relevant_test);
    print "trial none ($search_engine)\n";
    print "\tThis search engine is known to be non-functional.  You are encouraged\n";
    print "\tto adopt it from it's original author\n\t$maintainer.\n";
    print "\n";
}

sub test_cases {
    my($mode) = @_;

    ######################################################################
    $search_engine = 'AltaVista';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/zero_result';
    $query = '+LSAM +Bogus' . 'NoSuchWord';
    $date = 'Fri Oct  3 16:30:25 PDT 1997';
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/one_page_result';
    $query = '+LSAM +AutoSearch';
    test($mode, $TEST_RANGE, 2, 19);

    $file = 'test/AltaVista/two_page_result';
    $query = '+LSAM +ISI +work';
    test($mode, $TEST_GREATER_THAN, 22);


    ######################################################################
    $search_engine = 'AltaVista::Web';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/Web/zero_result';
    $query = '+LSAM +Bogus' . 'NoSuchWord';
    $date = 'Thu Oct 23 17:08:48 PDT 1997';
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/Web/one_page_result';
    $query = '+LSAM +AutoSearch';
    test($mode, $TEST_RANGE, 2, 19);

    $file = 'test/AltaVista/Web/two_page_result';
    $query = '+LSAM +ISI +work';
    test($mode, $TEST_GREATER_THAN, 22);

    ######################################################################
    $search_engine = 'AltaVista::AdvancedWeb';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/AdvancedWeb/zero_result';
    $query = 'LSAM and Bogus' . 'NoSuchWord';
    $date = 'Thu Oct 23 17:08:48 PDT 1997';
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/AdvancedWeb/one_page_result';
    $query = 'LSAM and AutoSearch';
    test($mode, $TEST_RANGE, 2, 19);

    $file = 'test/AltaVista/AdvancedWeb/two_page_result';
    $query = 'LSAM and ISI and work';
    test($mode, $TEST_GREATER_THAN, 22);

    ######################################################################
    $search_engine = 'AltaVista::News';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/News/multi_result';
    $query = 'perl';
    $date = 'Thu Oct 23 18:04:51 PDT 1997';
    test($mode, $TEST_GREATER_THAN, 70);   # 30 hits/page

    $file = 'test/AltaVista/News/zero_result';
    $query = '+perl +Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    ######################################################################
    $search_engine = 'AltaVista::AdvancedNews';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/AdvancedNews/multi_result';
    $query = 'perl';
    $date = 'Thu Oct 23 18:04:51 PDT 1997';
    test($mode, $TEST_GREATER_THAN, 70);   # 30 hits/page

    $file = 'test/AltaVista/AdvancedNews/zero_result';
    $query = 'perl and Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    ######################################################################
    $search_engine = 'DejaNews';
    $maintainer = 'Cesare Feroldi de Rosa, <C.Feroldi@IT.net>';
    not_working;

    ######################################################################
    $search_engine = 'Excite';
    # $maintainer = 'GLen Pringle <pringle@cs.monash.edu.au>';
    $maintainer = 'Martin Thurn <mthurn@irnet.rest.tasc.com>';

    $file = 'test/Excite/zero_result';
    $query = '+mrfglbqnx +Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    # 84 hits/page
    $file = 'test/Excite/one_page_result';
    $query = 'disestablishmentarianism';
    test($mode, $TEST_RANGE, 2, 80);

    $file = 'test/Excite/two_page_result';
    $query = '+Jabba +bounty +hunter +Greedo';
    test($mode, $TEST_GREATER_THAN, 86);

    ######################################################################
#    $search_engine = 'Gopher';
#    $maintainer = 'Paul Lindner <lindner@reliefweb.int>';
#    not_working;

    ######################################################################
    $search_engine = 'HotBot';
    $maintainer = 'Martin Thurn <mthurn@irnet.rest.tasc.com>';

    $file = 'test/HotBot/zero_result';
    $query = '"mrfglbqnx Bogus' . 'NoSuchWord"';
    test($mode, $TEST_EXACTLY);

    # 84 hits/page
    $file = 'test/HotBot/one_page_result';
    $query = '"Christie Abbott"';
    test($mode, $TEST_RANGE, 2, 80);

    $file = 'test/HotBot/two_page_result';
    $query = '+"Martin Thurn" +SWB';
    test($mode, $TEST_GREATER_THAN, 86);

    ######################################################################
    $search_engine = 'Infoseek';
    $maintainer = 'Cesare Feroldi de Rosa, <C.Feroldi@IT.net>';
    not_working;

    ######################################################################
    $search_engine = 'Lycos';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/Lycos/zero_result';
    $query = 'LSAM Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Lycos/one_page_result';
    $query = 'LSAM IB ISI';
    test($mode, $TEST_EXACTLY);

    # 10 hits/page
    $file = 'test/Lycos/two_page_result';
    $query = 'LSAM ISI';
    test($mode, $TEST_GREATER_THAN, 12);

    ######################################################################
    $search_engine = 'Magellan';
    $maintainer = 'Martin Thurn <mthurn@irnet.rest.tasc.com>';

    $file = 'test/Magellan/zero_result';
    $query = '+mrfglbqnx +Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Magellan/one_page_result';
    $query = 'disestablishmentarianism';
    test($mode, $TEST_RANGE, 2, 9);

    # 10 hits/page
    $file = 'test/Magellan/two_page_result';
    $query = '+Martin +Thurn';
    test($mode, $TEST_GREATER_THAN, 12);

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
    $search_engine = 'WebCrawler';
    $maintainer = 'Martin Thurn <mthurn@irnet.rest.tasc.com>';

    $file = 'test/WebCrawler/zero_result';
    $query = '+mrfglbqnx +Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/WebCrawler/one_page_result';
    $query = 'disestablishmentarianism';
    test($mode, $TEST_EXACTLY);

    $file = 'test/WebCrawler/two_page_result';
    $query = 'Greedo';
    test($mode, $TEST_EXACTLY);

    ######################################################################
    $search_engine = 'Yahoo';
    $maintainer = 'Martin Thurn <mthurn@irnet.rest.tasc.com>';
    $date = 'Mon Mar 30 22:25:59 PST 1998';

    $file = 'test/Yahoo/zero_result';
    $query = '"mrfglbqnx Bogus' . 'NoSuchWord"';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Yahoo/one_page_result';
    $query = 'LSAM';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Yahoo/two_page_result';
    $query = 'Star Wars';
    test($mode, $TEST_GREATER_THAN, 200);  # Yahoo seems to have 84 hits/page
}

sub main {
    $pwd = `pwd`;
    chomp($pwd);

    $fullperl = $Config{'perlpath'};

#    print "\n\nWWW::Search version " . $WWW::Search::VERSION . "\n";
    print "\nVERSION INFO:\n";
    my($cmd) = &web_search_bin . " -V";
    print `$cmd`;

    if ($update_saved_files) {
	&test_cases($MODE_UPDATE);
	return;
    };

    print "\nTESTING INTERNAL PARSING.\n\t(Errors here should be reported to the WWW::Search maintainer.)\n\n";
    &test_cases($MODE_INTERNAL);

    if (!$internal_only) {
        print "\n\nTESTING EXTERNAL QUERIES.\n\t(Errors here suggest search-engine remormatting and should be\n\treported to the maintainer of the back-end for the search engine.)\n\n";
        &test_cases($MODE_EXTERNAL);
    };
}

main;

exit 0;

# supress warnings
#my($x) = $WWW::Search::VERSION;
