#!/usr/local/bin/perl -w

# test.pl
# Copyright (C) 1997 by USC/ISI
# $Id: test.pl,v 1.31 1999/11/29 19:43:54 mthurn Exp $
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

sub usage 
  {
  print STDERR <<END;
usage: $0 [-dIXuv] [-e SearchEngine]

Runs WWW::Search tests.

Options:
    -e SearchEngine	limit actions to that search engine
    -u			update saved test files
    -v			verbose (show commands)
    -I			run interal tests only
    -X			run external tests only
END
  my $unused = <<'UNUSED';
To save a result to a file, use the search_to_file option of WebSearch.
Something like:

bin/WebSearch -e AltaVista::Web -o search_to_file=Test-Pages/AltaVista/Web/zero_result -- '+LSAM +No_SuchWord'
UNUSED
  exit 1;
  } # usage

use strict;

use Config;
use File::Path;
use Getopt::Long;
use WWW::Search;

use vars qw( $verbose $debug $desired_search_engine $mode $update_saved_files );
use vars qw( $do_internal $do_external );
$do_internal = $do_external = 0;
undef $debug;
&usage unless &GetOptions(
                          'd:i' => \$debug,
                          'e=s' => \$desired_search_engine,
                          'u' => \$update_saved_files,
                          'v' => \$verbose,
                          'I' => \$do_internal,
                          'X' => \$do_external,
                         );
($do_internal, $do_external) = (1,1) unless ($do_internal || $do_external);
$debug = 1 if (defined($debug) and ($debug < 1));

my $error_count = 0;
my $fullperl;
my ($date, $pwd);
my ($MODE_DUMMY, $MODE_INTERNAL, $MODE_EXTERNAL, $MODE_UPDATE) = qw(dummy internal external update);
my ($TEST_DUMMY, $TEST_EXACTLY, $TEST_BY_COUNTING, $TEST_GREATER_THAN, $TEST_RANGE) = (1..10);
my $bogus_query = "Bogus" . $$ . "NoSuchWord" . time;

&main();

exit 0;

sub relevant_test 
  {
  return 1 if (!defined($desired_search_engine));
  return ($desired_search_engine eq $_[0]);
  } # relevant_test

sub web_search_bin 
  {
  my $sDebug = $debug ? "--debug $debug" : '';
  return "$fullperl -I$pwd/lib $pwd/blib/script/WebSearch $sDebug ";
  }

sub eval_test
  {
  my $sSE = shift;
  return unless &relevant_test($sSE);
  my $o = new WWW::Search($sSE);
  my $iVersion = $o->version;
  my $code = $o->test_cases;
  $code ||= '';
  unless ($code ne '')
    {
    print "  $sSE version $iVersion contains no TEST_CASES\n";
    $error_count++;
    }
  # print STDERR "  $code\n" if $verbose;
  print "\n";  # put a little space between each engine's results
  eval $code;
  } # eval_test


# Several test methods are possible:
# $TEST_EXACTLY:  output must match exactly (line for line, in order)
# $TEST_BY_COUNTING:  test passes if number of lines is equal
# $TEST_GREATER_THAN:  test passes if we get more than N lines of output
# $TEST_RANGE:  like GREATER_THAN but constrained on both ends
#
sub test 
  {
  my $sSE = shift;
  my $sM = shift;
  my $file = shift;
  my $query = shift;
  my $test_method = shift;
  # print "  mode=$mode, method=$test_method\n";
  
  return if (!relevant_test($sSE));
  
  print "  trial $file ($mode)\n";
  if (($mode eq $MODE_INTERNAL) && ($query =~ m/$bogus_query/))
    {
    print "  skipping test on this platform.\n";
    return;
    } # if

  my $path = "$pwd/Test-Pages/$sSE";
  $path =~ s!::!\/!g;
  mkpath $path;
  if ($mode eq $MODE_UPDATE)
    {
    # Delete all existing test result files for this Engine:
    unlink <$path/$file*>;
    } # if MODE_UPDATE
  if ($file =~ m!([^/]+)$!)
    {
    # Prepend path onto file
    $file = $path.'/'.$1;
    } # if
  my $o = new WWW::Search($sSE);
  my $version = $o->version;
  print "  ($sSE $version, $sM)\n";
  my %src = (
             $MODE_INTERNAL => "--option search_from_file=$file",
             $MODE_EXTERNAL => '',
             $MODE_UPDATE => "--option search_to_file=$file",
            );
  # --max 201 added by Martin Thurn 1999-09-27, changed to 199 on
  # 1999-10-05.  We never want to fetch more than two pages, if we can
  # at all help it (or do we?)
  my $cmd = &web_search_bin . "--max 199 --engine $sSE $src{$mode} -- $query";
  print "  $cmd\n" if ($verbose);
  open(TRIALSTREAM, "$cmd|") || die "$0: cannot run test\n";
  open(TRIALFILE, ">$file.trial") || die "$0: cannot open $file.trial\n";
  open(OUTFILE, ">$file.out") || die "$0: cannot open $file.out\n" if ($mode eq $MODE_UPDATE);
  my $iActual = 0;
  while (<TRIALSTREAM>) 
    {
    print TRIALFILE $_;
    $iActual++;
    print OUTFILE $_ if ($mode eq $MODE_UPDATE);
    }
  close TRIALSTREAM;
  close TRIALFILE;
  if ($mode eq $MODE_UPDATE)
    {
    close OUTFILE;
    if (open TS, ">$file.README")
      {
      print TS "This set of test-result pages was created on ", scalar(localtime(time)), "\n";
      close TS;
      } # if
    my $iPageCount = &wc_l($file);
    my $iURLCount = &wc_l("$file.out");
    my $sExpected = join('..', @_);
    $sExpected .= '..' if ($test_method == $TEST_GREATER_THAN);
    $sExpected = 0 if $sExpected eq '';
    print "  $query --> $iURLCount urls (should be $sExpected) on $iPageCount pages\n";
    return;
    } # if

  if (-f "$file.out") 
    {
    my ($e, $sMsg) = (0, '');
    if ($test_method == $TEST_GREATER_THAN) 
      {
      my ($low_end) = @_;
      if ($iActual < $low_end)
        {
        $sMsg .= "expected more than $low_end, but got $iActual; ";
        $e = 1;
        }
      } # TEST_GREATER_THAN
    elsif ($test_method == $TEST_RANGE) 
      {
      my ($low_end, $high_end) = @_;
      $sMsg .= "INTERNAL ERROR, low_end has no value; " unless defined($low_end);
      $sMsg .= "INTERNAL ERROR, high_end has no value; " unless defined($high_end);
      $sMsg .= "INTERNAL ERROR, high_end is zero; " unless 0 < $high_end;
      if ($iActual < $low_end)
        {
        $sMsg .= "expected $low_end..$high_end, but got $iActual; ";
        $e = 1;
        }
      if ($high_end < $iActual)
        {
        $sMsg .= "expected $low_end..$high_end, but got $iActual; ";
        $e = 1;
        }
      } # TEST_RANGE
    elsif ($test_method == $TEST_EXACTLY) 
      {
      $e = &diff("$file.out", "$file.trial") ? 1 : 0;
      } # TEST_EXACTLY
    elsif ($test_method == $TEST_BY_COUNTING) 
      {
      my $iExpected = shift;
      my $iActual = &wc_l("$file.trial");
      if ($iActual != $iExpected)
        {
        $sMsg .= "expected $iExpected, but got $iActual; ";
        $e = 1;
        }
      }
    else
      {
      $e = 0;
      $sMsg = "INTERNAL ERROR, unknown test method $test_method; ";
      }

    if ($e == 0) 
      {
      print "  ok.\n";
      unlink("$file.trial");   # clean up
      } 
    elsif ($e == 1) 
      {
      print "DIFFERENCE DETECTED: $query --> $sMsg\n";
      $error_count++;
      }
    else 
      {
      print "INTERNAL ERROR $query --> e is $e.\n";
      $error_count++;
      }
    } 
  else 
    {
    print "NO SAVED OUTPUT.\n";
    }
  } # test

sub no_test 
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print <<"NONE";
  trial none ($engine)
  This search engine doesn't have any tests,
  but report problems with it to $maint.
NONE
  } # no_test

sub not_working 
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print <<"BROKEN";
  trial none ($engine)
  This search engine is known to be non-functional.  
  You are encouraged to investigate the problem and email its maintainer, 
  $maint.
BROKEN
  } # not_working

sub not_working_with_tests 
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print <<"KNOWNFAILURE";
  trial none ($engine)
  Test cases for this search engine are known to fail.  
  You are encouraged to investigate the problem and email its maintainer,
  $maint.
KNOWNFAILURE
  } # not_working_with_tests 

sub not_working_and_abandonded
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print <<"ADOPT";
  trial none ($engine)
  This search engine is known to be non-functional.  
  You are encouraged to adopt it from its last known maintainer, 
  $maint.
ADOPT
  } # not_working_and_abandonded
        
sub test_cases 
  {
  my ($o, $query, $sSE, $sM, $file);

  $sSE = 'AltaVista';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'zero_result_no_plus';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'zero_result';
  $query = '+LSAM +' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  $file = 'one_page_result';
  $query = '+LS'.'AM +Aut'.'oSearch';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 10);
  
  $file = 'two_page_result';
  $query = '+LS'.'AM +IS'.'I +Heide'.'mann';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################

  $sSE = 'AltaVista::Web';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'zero_result';
  $query = '+LSA'.'M +' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  $file = 'one_page_result';
  $query = '+LSA'.'M +AutoSea'.'rch';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 10);
  
  $file = 'two_page_result';
  $query = '+LSA'.'M +IS'.'I +I'.'B';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################

  $sSE = 'AltaVista::AdvancedWeb';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'zero_result';
  $query = 'LS'.'AM and ' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  $file = 'one_page_result';
  $query = 'LSA'.'M and AutoSea'.'rch';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 11);
  
  $file = 'two_page_result';
  $query = 'LSA'.'M and IS'.'I and I'.'B';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################

  $sSE = 'AltaVista::News';
  $sM = 'John Heidemann <johnh@isi.edu>';
  &not_working($sSE, $sM);
  # $query = '+pe'.'rl +' . $bogus_query;
  # test($sSE, $sM, 'zero', $query, $TEST_EXACTLY);
  # $query = '+Pe'.'rl +CP'.'AN';
  # test($sSE, $sM, 'multi', $query, $TEST_GREATER_THAN, 30); # 30 hits/page
  
  ######################################################################

  $sSE = 'AltaVista::AdvancedNews';
  $sM = 'John Heidemann <johnh@isi.edu>';
  &not_working($sSE, $sM);
  # $query = 'per'.'l and ' . $bogus_query;
  # test($sSE, $sM, 'zero', $query, $TEST_EXACTLY);
  # $query = 'Per'.'l and CP'.'AN';
  # test($sSE, $sM, 'multi', $query, $TEST_GREATER_THAN, 70); # 30 hits/page
  
  ######################################################################

  &eval_test('AltaVista::Intranet');

  ######################################################################

  &no_test('Crawler', 'unsupported');
  # test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  # $query = 'Bay'.'reuth Bindl'.'acher Be'.'rg Flu'.'gplatz P'.'ilot';
  # test($sSE, $sM, 'one', $query, $TEST_RANGE, 2, 10);
  # # 10 hits/page
  # $query = 'Fra'.'nkfurter Al'.'lgemeine Sonnt'.'agszeitung Rech'.'erche';
  # test($sSE, $sM, 'two', $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################

  &eval_test('Dejanews');
  
  &eval_test('Excite');
  &eval_test('Excite::News');

  ######################################################################

  $sSE = 'ExciteForWebServers';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  &not_working($sSE, $sM);
  # &test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  # $query = 'bur'.'undi';
  # &test($sSE, $sM, 'one', $query, $TEST_RANGE, 2, 99);
  
  ######################################################################

  $sSE = 'Fireball';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  &no_test($sSE, $sM);
  # 10 hits/page
  test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  $query = 'charmeleon';
  test($sSE, $sM, 'one', $query, $TEST_RANGE, 1, 10);
  # $query = '+Mu'.'rnau +Hinterg'.'lasbilder';
  # test($sSE, $sM, 'two', $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################

  $sSE = 'FolioViews';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  $query = 'bur'.'undi';
  test($sSE, $sM, 'one', $query, $TEST_RANGE, 2, 400);
  
  ######################################################################

  &eval_test('Google');
  
  &no_test('Gopher', 'Paul Lindner <paul.lindner@itu.int>');

  &eval_test('GoTo');
  
  &eval_test('HotBot');
  
  &eval_test('HotFiles');
  
  &eval_test('Infoseek::Companies');
  &eval_test('Infoseek::Email');
  &eval_test('Infoseek::News');
  &eval_test('Infoseek::Web');

  &no_test('Livelink', 'Paul Lindner <paul.lindner@itu.int>');

  &eval_test('LookSmart');
  # use WWW::Search::LookSmart;
  # &no_test('LookSmart', $WWW::Search::LookSmart::MAINTAINER);

  &eval_test('Lycos::Pages');
  &eval_test('Lycos::Sites');
  
  &eval_test('Magellan');
  
  &eval_test('MetaCrawler', 'Jim Smyser <jsmyser@bigfoot.com>');
  
  ######################################################################

  $sSE = 'Metapedia';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  $file = 'test/Metapedia/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  ######################################################################

  $sSE = 'MSIndexServer';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  &not_working($sSE, $sM);
  # test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  # $query = 'bur'.'undi';
  # test($sSE, $sM, 'one', $query, $TEST_RANGE, 2, 99);
  
  ######################################################################

  &eval_test('NetFind');

  &eval_test('NorthernLight');
  
  ######################################################################

  $sSE = 'Null';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  
  ######################################################################

  &eval_test('OpenDirectory');
  
  ######################################################################

  $sSE = 'PLweb';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  &not_working($sSE, $sM);
  # test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  # $query = 'bur'.'undi';
  # test($sSE, $sM, 'one', $query, $TEST_RANGE, 2, 99);
  
  ######################################################################

  &eval_test('Profusion');
  
  ######################################################################

  $sSE = 'Search97';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  &not_working($sSE, $sM);
  # $file = 'test/Search97/zero_result';
  # test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  # $file = 'test/Search97/one_page_result';
  # $query = 'bur'.'undi';
  # test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99);
  
  ######################################################################

  $sSE = 'SFgate';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  test($sSE, $sM, 'zero', $bogus_query, $TEST_EXACTLY);
  $query = 'bur'.'undi';
  test($sSE, $sM, 'one', $query, $TEST_RANGE, 2, 99);
  
  ######################################################################

  &no_test('Simple', 'Paul Lindner <paul.lindner@itu.int>');

  &eval_test('Snap');
  
  &no_test('Verity', 'Paul Lindner <paul.lindner@itu.int>');

  &eval_test('WebCrawler');
  
  &eval_test('Yahoo');

  &eval_test('ZDNet');

  } # test_cases
  

sub main 
  {
  use Cwd;
  $pwd = cwd;
  $fullperl = $Config{'perlpath'};
  
  print "\nVERSION INFO:\n  ";
  my ($cmd) = &web_search_bin . " --VERSION";
  print `$cmd`;
  
  if ($update_saved_files) 
    {
    print "\nUPDATING.\n\n";
    $mode = $MODE_UPDATE;
    &test_cases();
    # Can not do update AND test:
    return;
    } # if
  
  if ($do_internal) 
    {
    print "\nTESTING INTERNAL PARSING.\n  (Errors here should be reported to the WWW::Search maintainer.)\n\n";
    $error_count = 0;
    $mode = $MODE_INTERNAL;
    &test_cases();
    print "\n";
    if ($error_count <= 0) 
      {
      print "All $mode tests have passed.\n\n";
      }
    else 
      {
      print "Some $mode tests failed.  Please check the README file before reporting errors (sometimes back-ends have known failures).\n";
      }
    } # if $do_internal
    
  if ($do_external) 
    {
    print "\n\nTESTING EXTERNAL QUERIES.\n  (Errors here suggest search-engine reformatting and should be\n  reported to the maintainer of the back-end for the search engine.)\n\n";
    $error_count = 0;
    $mode = $MODE_EXTERNAL;
    &test_cases();
    print "\n";
    if ($error_count <= 0) 
      {
      print "All $mode tests have passed.\n\n";
      }
    else 
      {
      print "Some $mode tests failed.  Please check the README file before reporting errors (sometimes back-ends have known failures).\n";
      }
    } # if $do_external
  
  } # main

sub wc_l
  {
  # Given a filename, count the number of lines of text contained
  # within the file.  (I.e. simulate running UNIX command wc -l on it)
  # SPECIAL CASE: If first line is "Nothing found.", report 0 lines.
  open WC, shift or return 0;
  $/ = "\n";
  my $i = 0;
  while (<WC>)
    {
    last if /Nothing found./;
    $i++;
    } # while
  return $i;
  } # wc_l

sub diff
  {
  # Given two files, returns TRUE if contents are line-by-line
  # different, or FALSE if contents are line-by-line same
  open DIFF1, shift or return 91;
  open DIFF2, shift or return 92;
  my $iResult = 0;
  $/ = "\n";
  while ((defined(my $s1 = <DIFF1>)) &&
         ($iResult ne 1))
    {
    my $s2 = <DIFF2>;
    unless (defined($s2))
      {
      $iResult = 1;
      last;
      }
    chomp $s1;
    chomp $s2;
    if ($s1 ne $s2)
      {
      $iResult = 1;
      last;
      }
    } # while
  close DIFF1;
  close DIFF2;
  return $iResult;
  } # diff


=head2 TO DO

=item  No identified needs at the moment...

=cut

=head2 HOW IT WORKS

At present there is only one function available, namely &test().  It
takes at least 5 arguments.  These are: 1) the name of the search
engine (string); 2) the maintainer's name (and email address)
(string); 3) a filename (unique among tests for this backend)
(string); 4) the raw query string; 5) the test method (one of the
constants $TEST_EXACTLY, $TEST_RANGE, $TEST_GREATER_THAN,
$TEST_BY_COUNTING); optional arguments 6 and 7 are integers to be used
when counting the results.

The query is sent to the engine, and the results are compared to
previously stored results as follows: If the method is $TEST_EXACTLY,
the two lists of URLs must match exactly.  If the method is
$TEST_RANGE, the number of URLs must be between arg6 and arg7.  If the
method is $TEST_GREATER_THAN, the number of URLs must be greater than
arg6.  If the method is $TEST_BY_COUNTING, the number of URLs must be
exactly arg6 (but we don't care what the URLs are).

=cut

