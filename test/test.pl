#!/home/johnh/BIN/perl5 -w

#
# test.pl
# Copyright (C) 1997 by USC/ISI
# $Id: test.pl,v 1.29 1998/12/11 23:07:41 johnh Exp $
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
    -X			run external tests only


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
&GetOptions(\%opts, qw(d e=s X I u v));
# &usage if ($#ARGV < 0);


my($verbose) = $opts{'v'};
my($debug) = $opts{'d'};
my($desired_search_engine) = $opts{'e'};
my($update_saved_files) = $opts{'u'};
my($do_internal, $do_external);
if ($opts{'I'} && $opts{'X'}) {
    ($do_internal, $do_external) = (1,1);
} elsif ($opts{'I'}) {
    ($do_internal, $do_external) = (1,0);
} elsif ($opts{'X'}) {
    ($do_internal, $do_external) = (0,1);
} else {
    ($do_internal, $do_external) = (1,1);
};
my($error_count) = 0;

my($fullperl);
my($file, $query, $date, $search_engine, $pwd, $maintainer);

my($MODE_DUMMY, $MODE_INTERNAL, $MODE_EXTERNAL, $MODE_UPDATE) = (0..10);

my($TEST_DUMMY, $TEST_EXACTLY, $TEST_BY_COUNTING, $TEST_GREATER_THAN, $TEST_RANGE) = (1..10);

my($bogus_query) = "Bogus" . "NoSuchWord" . "SpammersAreIdiots";

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
	    $error_count++;
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

sub not_working_with_tests {
    return if (!relevant_test);
    print "trial none ($search_engine)\n";
    print "\tThis search engine is known to be non-functional.  You are encouraged\n";
    print "\tto investigate the problem or send mail to its maintainer\n\t$maintainer.\n";
    print "\t(The test sets below are known to fail.)\n";
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

    $file = 'test/AltaVista/zero_result_no_plus';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/zero_result';
    $query = '+LSAM +' . $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/one_page_result';
    $query = '+LS' . 'AM +AutoSearch';
    test($mode, $TEST_RANGE, 2, 10);

    $file = 'test/AltaVista/two_page_result';
    $query = '+LSA' . 'M +ISI +IB';
    test($mode, $TEST_GREATER_THAN, 10);


    ######################################################################
    $search_engine = 'AltaVista::Web';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/Web/zero_result';
    $query = '+LSA' . 'M +' . $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/Web/one_page_result';
    $query = '+LSA' . 'M +AutoSearch';
    test($mode, $TEST_RANGE, 2, 10);

    $file = 'test/AltaVista/Web/two_page_result';
    $query = '+LSA' . 'M +ISI +IB';
    test($mode, $TEST_GREATER_THAN, 10);

    ######################################################################
    $search_engine = 'AltaVista::AdvancedWeb';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/AdvancedWeb/zero_result';
    $query = 'LS' . 'AM and ' . $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/AltaVista/AdvancedWeb/one_page_result';
    $query = 'LSA' . 'M and AutoSearch';
    test($mode, $TEST_RANGE, 2, 11);

    $file = 'test/AltaVista/AdvancedWeb/two_page_result';
    $query = 'LSA' . 'M and ISI and IB';
    test($mode, $TEST_GREATER_THAN, 10);

    ######################################################################
    $search_engine = 'AltaVista::News';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/News/multi_result';
    $query = '+Pe' . 'rl +CPAN';
    test($mode, $TEST_GREATER_THAN, 30);   # 30 hits/page

    $file = 'test/AltaVista/News/zero_result';
    $query = '+pe' . 'rl +' . $bogus_query;
    test($mode, $TEST_EXACTLY);

    ######################################################################
    $search_engine = 'AltaVista::AdvancedNews';
    $maintainer = 'John Heidemann <johnh@isi.edu>';

    $file = 'test/AltaVista/AdvancedNews/multi_result';
    $query = 'Per' . 'l and CPAN';
    test($mode, $TEST_GREATER_THAN, 70);   # 30 hits/page

    $file = 'test/AltaVista/AdvancedNews/zero_result';
    $query = 'per' . 'l and ' . $bogus_query;
    test($mode, $TEST_EXACTLY);

    ######################################################################
    $search_engine = 'Crawler';
    $maintainer = 'unsupported';

    $file = 'test/Crawler/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Crawler/one_page_result';
    $query = 'Bay' . 'reuth Bindlacher Berg Flugplatz Pilot';
    test($mode, $TEST_RANGE, 2, 10);

    # 10 hits/page
    $file = 'test/Crawler/two_page_result';
    $query = 'Fran' . 'kfurter Allgemeine Sonntagszeitung Recherche';
    test($mode, $TEST_GREATER_THAN, 10);

    ######################################################################
    $search_engine = 'Dejanews';
    # $maintainer = 'Cesare Feroldi de Rosa, <C.Feroldi@IT.net>';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/Dejanews/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Dejanews/multi_result';
    $query = 'Per' . 'l and CPAN';
    test($mode, $TEST_GREATER_THAN, 101);


    ######################################################################
    $search_engine = 'Excite';
    # $maintainer = 'GLen Pringle <pringle@cs.monash.edu.au>';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/Excite/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    # 84 hits/page
    $file = 'test/Excite/one_page_result';
    $query = 'dis' . 'establishmentarianism';
    test($mode, $TEST_RANGE, 2, 80);

    $file = 'test/Excite/two_page_result';
    $query = '+Ja' . 'bba +bounty +hunter +Greedo';
    test($mode, $TEST_GREATER_THAN, 86);

    ######################################################################
    $search_engine = 'ExciteForWebServers';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/ExciteForWebServers/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/ExciteForWebServers/one_page_result';
    $query = 'bur' . 'undi';
    test($mode, $TEST_RANGE, 2, 99);

    ######################################################################
    $search_engine = 'Fireball';
    $maintainer = 'unsupported';

    $file = 'test/Fireball/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Fireball/one_page_result';
    $query = '+An' . 'na +Kournikova +Wimbledon +WTA +tennis';
    test($mode, $TEST_RANGE, 2, 10);

    # 10 hits/page
    $file = 'test/Fireball/two_page_result';
    $query = '+Mu' . 'rnau +Hinterglasbilder';
    test($mode, $TEST_GREATER_THAN, 10);

    ######################################################################
    $search_engine = 'FolioViews';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/FolioViews/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/FolioViews/one_page_result';
    $query = 'bur' . 'undi';
    test($mode, $TEST_RANGE, 2, 400);

    ######################################################################
    $search_engine = 'Gopher';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';
    no_test;

    ######################################################################
    $search_engine = 'HotBot';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/HotBot/zero_result';
    $query = '"mr' . 'fglbqnx ' . $bogus_query . '"';
    test($mode, $TEST_EXACTLY);

    # 84 hits/page
    $file = 'test/HotBot/one_page_result';
    $query = '"Ch' . 'ristie Abbott"';
    test($mode, $TEST_RANGE, 2, 80);

    $file = 'test/HotBot/two_page_result';
    $query = '+LS' . 'AM +ISI';
    test($mode, $TEST_GREATER_THAN, 86);

    ######################################################################
    $search_engine = 'Infoseek';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/Infoseek/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    # default infoseek back-end has 50 hits/page
    $file = 'test/Infoseek/one_page_result';
    $query = 'Mar' . 'tin Thurn AND Star Wars';
    test($mode, $TEST_RANGE, 2, 24);

    $file = 'test/Infoseek/two_page_result';
    $query = 'Gre' . 'edo AND collectible';
    test($mode, $TEST_GREATER_THAN, 25);


    $search_engine = 'Infoseek::Web';

    $file = 'test/Infoseek/Web/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Infoseek/Web/one_page_result';
    $query = 'Mar' . 'tin Thurn AND Star Wars';
    test($mode, $TEST_RANGE, 2, 24);

    $file = 'test/Infoseek/Web/two_page_result';
    $query = 'Gre' . 'edo AND collectible';
    test($mode, $TEST_GREATER_THAN, 25);


    $search_engine = 'Infoseek::Companies';

    $file = 'test/Infoseek/Companies/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Infoseek/Companies/one_page_result';
    $query = 'Pac' . 'ific AND travel';
    test($mode, $TEST_RANGE, 2, 24);

    $file = 'test/Infoseek/Companies/two_page_result';
    $query = 'pri' . 'son';
    test($mode, $TEST_GREATER_THAN, 25);


    $search_engine = 'Infoseek::News';

    $file = 'test/Infoseek/News/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Infoseek/News/nonzero_result';
    $query = 'Haw' . 'aii';
    test($mode, $TEST_GREATER_THAN, 2);


    ######################################################################
    $search_engine = 'Livelink';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';
    no_test;


    ######################################################################
    $search_engine = 'Lycos';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/Lycos/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Lycos/one_page_result';
    $query = '"Chri'.'stie Ab'.'bott"';
    test($mode, $TEST_RANGE, 2, 50);

    $file = 'test/Lycos/multi_page_result';
    $query = 'repli'.'cation';
    test($mode, $TEST_GREATER_THAN, 100);

    ######################################################################
    $search_engine = 'Magellan';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/Magellan/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Magellan/one_page_result';
    $query = 'dis' . 'establishmentarianism';
    test($mode, $TEST_RANGE, 1, 9);

    # 10 hits/page
    $file = 'test/Magellan/two_page_result';
    $query = '+IS' . 'I +divisions';
    test($mode, $TEST_GREATER_THAN, 11);


    ######################################################################
    $search_engine = 'MSIndexServer';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/MSIndexServer/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/MSIndexServer/one_page_result';
    $query = 'bur' . 'undi';
    test($mode, $TEST_RANGE, 2, 99);


    ######################################################################
    $search_engine = 'NorthernLight';
    $maintainer = 'unsupported';

    $file = 'test/NorthernLight/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/NorthernLight/one_page_result';
    $query = '+Bi' . 'athlon +weltcups +Athleten +deutschland';
    test($mode, $TEST_RANGE, 2, 25);

    # 25 hits/page
    $file = 'test/NorthernLight/two_page_result';
    $query = '+LS' . 'AM +ISI +IB';
    test($mode, $TEST_GREATER_THAN, 25);


    ######################################################################
    $search_engine = 'Null';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/Null/zero_result';
    $query = 'any' . 'term';
    test($mode, $TEST_EXACTLY);


    ######################################################################
    $search_engine = 'PLweb';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/PLweb/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/PLweb/one_page_result';
    $query = 'bur' . 'undi';
    test($mode, $TEST_RANGE, 2, 99);


    ######################################################################
    $search_engine = 'Search97';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/Search97/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Search97/one_page_result';
    $query = 'bur' . 'undi';
    test($mode, $TEST_RANGE, 2, 99);


    ######################################################################
    $search_engine = 'SFgate';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';

    $file = 'test/SFgate/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/SFgate/one_page_result';
    $query = 'bur' . 'undi';
    test($mode, $TEST_RANGE, 2, 99);


    ######################################################################
    $search_engine = 'Snap';
    $maintainer = 'Jim Smyser <jsmyser@bigfoot.com>';

    $file = 'test/Snap/zero_result'; 
    $query = $bogus_query; 
    test($mode, $TEST_EXACTLY); 
     
    $file = 'test/Snap/one_page_result'; 
    $query = '"WW' . 'W::Search"'. '"Jim Smyser"'; 
    test($mode, $TEST_RANGE, 2, 99); 
      
    $file = 'test/Snap/multi_page_result'; 
    $query = '+di' . 'v7 +ISI';
    test($mode, $TEST_GREATER_THAN, 100); 

    ######################################################################
    $search_engine = 'Simple';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';
    no_test;


    ######################################################################
    $search_engine = 'Verity';
    $maintainer = 'Paul Lindner <paul.lindner@itu.int>';
    no_test;


    ######################################################################
    $search_engine = 'WebCrawler';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/WebCrawler/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/WebCrawler/one_page_result';
    $query = 'dis' . 'establishmentarianism';
    test($mode, $TEST_RANGE, 2, 99);

    $file = 'test/WebCrawler/two_page_result';
    $query = 'Gre' . 'edo';
    test($mode, $TEST_GREATER_THAN, 100);


    ######################################################################
    $search_engine = 'Yahoo';
    $maintainer = 'Martin Thurn <MartinThurn@iname.com>';

    $file = 'test/Yahoo/zero_result';
    $query = $bogus_query;
    test($mode, $TEST_EXACTLY);

    $file = 'test/Yahoo/one_page_result';
    $query = 'LSA' . 'M';
    test($mode, $TEST_RANGE, 2, 84);

    $file = 'test/Yahoo/two_page_result';
    $query = 'rep' . 'lication';
    test($mode, $TEST_GREATER_THAN, 100);  # Yahoo seems to have 84 hits/page
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
        print "\nUPDATING.\n\n";
	&test_cases($MODE_UPDATE);
	return;
    };

    if ($do_internal) {
        print "\nTESTING INTERNAL PARSING.\n\t(Errors here should be reported to the WWW::Search maintainer.)\n\n";
	&test_cases($MODE_INTERNAL);
    };

    if ($do_external) {
        print "\n\nTESTING EXTERNAL QUERIES.\n\t(Errors here suggest search-engine reformatting and should be\n\treported to the maintainer of the back-end for the search engine.)\n\n";
        &test_cases($MODE_EXTERNAL);
    };

    if ($error_count == 0) {
	print "All tests have passed.\n\n";
    } else {
	print "Some tests failed.  Please check the README file in the distribution\nbefore reporting errors (sometimes back-ends have known failures :-( ).\n\n";
    };
}

main;

exit 0;

# supress warnings
#my($x) = $WWW::Search::VERSION;
