#!/usr/local/bin/perl -w

# test.pl
# Copyright (C) 1997 by USC/ISI
# $Id: test.pl,v 1.7 1999/06/30 20:21:21 mthurn Exp $
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

bin/WebSearch -e AltaVista::Web -o search_to_file=test/Pages/AltaVista/Web/zero_result -- '+LSAM +No_SuchWord'
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
&usage unless &GetOptions(
                          'd' => \$debug,
                          'e=s' => \$desired_search_engine,
                          'u' => \$update_saved_files,
                          'v' => \$verbose,
                          'I' => \$do_internal,
                          'X' => \$do_external,
                         );
($do_internal, $do_external) = (1,1) unless ($do_internal || $do_external);

my $error_count = 0;
my($fullperl);
my ($date, $pwd);
my($MODE_DUMMY, $MODE_INTERNAL, $MODE_EXTERNAL, $MODE_UPDATE) = (0..10);
my($TEST_DUMMY, $TEST_EXACTLY, $TEST_BY_COUNTING, $TEST_GREATER_THAN, $TEST_RANGE) = (1..10);
my($bogus_query) = "Bogus" . "NoSuchWord" . "SpammersAreIdiots";

&main();

exit 0;

sub relevant_test 
  {
  return 1 if (!defined($desired_search_engine));
  return ($desired_search_engine eq $_[0]);
  } # relevant_test

sub web_search_bin 
  {
  return "$fullperl -I$pwd/lib $pwd/bin/WebSearch ";
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
    print "\t$sSE version $iVersion contains no TEST_CASES\n";
    $error_count++;
    }
  # print STDERR "\t$code\n" if $verbose;
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
  # print "\tmode=$mode, method=$test_method\n";
  
  return if (!relevant_test($sSE));
  
  my $path = "test/Pages/$sSE";
  $path =~ s!::!\/!g;
  mkpath $path;
  if ($file =~ m!([^/]+)$!)
    {
    $file = $path.'/'.$1;
    } # if
  my $o = new WWW::Search($sSE);
  my $version = $o->version;
  print "trial $file\n\t($sSE $version, $sM)\n";
  my(@src);
  my(@output) = ();
  $src[$MODE_INTERNAL] = "-o search_from_file=$file";
  $src[$MODE_EXTERNAL] = "";
  $src[$MODE_UPDATE] = "-o search_to_file=$file";
  my($cmd) = &web_search_bin . "-e $sSE $src[$mode] -- '$query'";
  # $cmd .= " | wc -l | sed 's/ //g'" if ($test_method == $TEST_BY_COUNTING && $mode != $MODE_UPDATE);
  print "\t$cmd\n" if ($verbose);
  open(TRIALSTREAM, "$cmd|") || die "$0: cannot run test\n";
  open(TRIALFILE, ">$file.trial") || die "$0: cannot open $file.trial\n";
  open(OUTFILE, ">$file.out") || die "$0: cannot open $file.out\n" if ($mode == $MODE_UPDATE);
  while (<TRIALSTREAM>) 
    {
    last if /Nothing found./;
    print TRIALFILE $_;
    print OUTFILE $_ if ($mode == $MODE_UPDATE);
    push(@output, $_);
    }
  close TRIALSTREAM;
  close TRIALFILE;
  if ($mode == $MODE_UPDATE)
    {
    close OUTFILE;
    if (open TS, ">$file.README")
      {
      print TS "This set of test-result pages was created on ", scalar(localtime(time)), "\n";
      close TS;
      } # if
    my $iPageCount = ` wc -l $file `;
    my $iURLCount = ` wc -l $file.out `;
    $iPageCount =~ s/\D+//g;
    $iURLCount =~ s/\D+//g;
    my $sExpected = join('..', @_);
    $sExpected .= '..' if ($test_method == $TEST_GREATER_THAN);
    print "\t$query --> $iURLCount urls (should be $sExpected) on $iPageCount pages\n";
    return;
    } # if

  if (-f "$file.out") 
    {
    my ($e, $sMsg) = (0, '');
    if ($test_method == $TEST_GREATER_THAN) 
      {
      my ($low_end) = @_;
      my $iActual = scalar(@output);
      if ($iActual < $low_end)
        {
        $sMsg .= ": expected more than $low_end, but got $iActual";
        $e = 1;
        }
      } # TEST_GREATER_THAN
    elsif ($test_method == $TEST_RANGE) 
      {
      my ($low_end, $high_end) = @_;
      $sMsg .= ": INTERNAL ERROR, low_end has no value" unless defined($low_end);
      $sMsg .= ": INTERNAL ERROR, high_end has no value" unless defined($high_end);
      $sMsg .= ": INTERNAL ERROR, high_end is zero" unless 0 < $high_end;
      my $iActual = scalar(@output);
      if ($iActual < $low_end)
        {
        $sMsg .= ": expected $low_end..$high_end, but got $iActual";
        $e = 1;
        }
      if ($high_end < $iActual)
        {
        $sMsg .= ": expected $low_end..$high_end, but got $iActual";
        $e = 1;
        }
      } # TEST_RANGE
    elsif ($test_method == $TEST_EXACTLY) 
      {
      my $cmd = "diff -c $file.out $file.trial > $file.diff";
      print "\t$cmd\n" if $verbose;
      print STDERR ` $cmd `;
      $e = (0 < -s "$file.diff") ? 1 : 0;
      } # TEST_EXACTLY
    elsif ($test_method == $TEST_BY_COUNTING) 
      {
      my $iExpected = shift;
      my $cmd = "wc -l $file.trial";
      print "\t$cmd\n" if $verbose;
      my $iActual = ` $cmd `;
      $iActual = $1 if $iActual =~ m/(\d+)/;
      if ($iActual != $iExpected)
        {
        $sMsg .= ": expected $iExpected, but got $iActual";
        $e = 1;
        }
      }
    else
      {
      $e = 0;
      $sMsg = ": INTERNAL ERROR, unknown test method $test_method";
      }

    if ($e == 0) 
      {
      print "\tok.\n";
      unlink("$file.trial");   # clean up
      unlink("$file.diff");   # clean up
      } 
    elsif ($e == 1) 
      {
      print "\t$query --> DIFFERENCE DETECTED$sMsg.\n";
      $error_count++;
      }
    else 
      {
      print "\t$query --> DIFF ERROR.\n";
      $error_count++;
      }
    } 
  else 
    {
    print "\tno saved output.\n";
    }
  print "\n";
  } # test

sub no_test 
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print "trial none ($engine)\n";
  print "\tThis search engine doesn't have any tests,\n";
  print "\tbut report problems for it to\n\t$maint.\n";
  print "\n";
  } # no_test

sub not_working 
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print "trial none ($engine)\n";
  print "\tThis search engine is known to be non-functional.  You are encouraged\n";
  print "\tto investigate the problem or send mail to its maintainer\n\t$maint.\n";
  print "\n";
  } # not_working

sub not_working_with_tests 
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print "trial none ($engine)\n";
  print "\tThis search engine is known to be non-functional.  You are encouraged\n";
  print "\tto investigate the problem or send mail to its maintainer\n\t$maint.\n";
  print "\t(The test sets below are known to fail.)\n";
  print "\n";
  } # not_working_with_tests 

sub not_working_and_abandonded
  {
  my ($engine, $maint) = @_;
  return if (!relevant_test($engine));
  print "trial none ($engine)\n";
  print "\tThis search engine is known to be non-functional.  You are encouraged\n";
  print "\tto adopt it from its original author\n\t$maint.\n";
  print "\n";
  } # not_working_and_abandonded
        
sub test_cases 
  {
  my ($o, $query, $sSE, $sM, $file);
  ######################################################################
  $sSE = 'AltaVista';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'test/AltaVista/zero_result_no_plus';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/AltaVista/zero_result';
  $query = '+LSAM +' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  $file = 'test/AltaVista/one_page_result';
  $query = '+LS'.'AM +Aut'.'oSearch';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 10);
  
  $file = 'test/AltaVista/two_page_result';
  $query = '+LS'.'AM +IS'.'I +I'.'B';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################
  $sSE = 'AltaVista::Web';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'test/AltaVista/Web/zero_result';
  $query = '+LSA'.'M +' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  $file = 'test/AltaVista/Web/one_page_result';
  $query = '+LSA'.'M +AutoSea'.'rch';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 10);
  
  $file = 'test/AltaVista/Web/two_page_result';
  $query = '+LSA'.'M +IS'.'I +I'.'B';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################
  $sSE = 'AltaVista::AdvancedWeb';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'test/AltaVista/AdvancedWeb/zero_result';
  $query = 'LS'.'AM and ' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  $file = 'test/AltaVista/AdvancedWeb/one_page_result';
  $query = 'LSA'.'M and AutoSea'.'rch';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 11);
  
  $file = 'test/AltaVista/AdvancedWeb/two_page_result';
  $query = 'LSA'.'M and IS'.'I and I'.'B';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################
  $sSE = 'AltaVista::News';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'test/AltaVista/News/multi_result';
  $query = '+Pe'.'rl +CP'.'AN';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 30); # 30 hits/page
  
  $file = 'test/AltaVista/News/zero_result';
  $query = '+pe'.'rl +' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  ######################################################################
  $sSE = 'AltaVista::AdvancedNews';
  $sM = 'John Heidemann <johnh@isi.edu>';
  
  $file = 'test/AltaVista/AdvancedNews/multi_result';
  $query = 'Per'.'l and CP'.'AN';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 70); # 30 hits/page
  
  $file = 'test/AltaVista/AdvancedNews/zero_result';
  $query = 'per'.'l and ' . $bogus_query;
  test($sSE, $sM, $file, $query, $TEST_EXACTLY);
  
  ######################################################################

  &no_test('AltaVista::Intranet', 'Martin Thurn <MartinThurn@iname.com>');

  ######################################################################

  $sSE = 'Crawler';
  $sM = 'unsupported';
  
  $file = 'test/Crawler/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Crawler/one_page_result';
  $query = 'Bay'.'reuth Bindl'.'acher Be'.'rg Flu'.'gplatz P'.'ilot';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 10);
  
  # 10 hits/page
  $file = 'test/Crawler/two_page_result';
  $query = 'Fra'.'nkfurter Al'.'lgemeine Sonnt'.'agszeitung Rech'.'erche';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################
  $sSE = 'Dejanews';
  # $sM = 'Cesare Feroldi de Rosa, <C.Feroldi@IT.net>';
  $sM = 'Martin Thurn <MartinThurn@iname.com>';
  
  $file = 'test/Dejanews/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Dejanews/multi_result';
  $query = 'Per'.'l and CP'.'AN';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 101);
  
  ######################################################################

  &eval_test('Excite');

  ######################################################################

  $sSE = 'Excite::News';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  test($sSE, $sM, 'zero', $bogus_query, $TEST_BY_COUNTING, 0);
  test($sSE, $sM, 'one', 'Haw'.'aii AND Alask'.'a', $TEST_RANGE, 1,49);
  test($sSE, $sM, 'multi', 'pris'.'on* AND esca'.'pe*', $TEST_GREATER_THAN, 51);

  ######################################################################

  $sSE = 'ExciteForWebServers';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/ExciteForWebServers/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/ExciteForWebServers/one_page_result';
  $query = 'bur'.'undi';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99);
  
  ######################################################################
  $sSE = 'Fireball';
  $sM = 'unsupported';
  
  $file = 'test/Fireball/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Fireball/one_page_result';
  $query = '+An'.'na +Kour'.'nikova +Wim'.'bledon +W'.'T'.'A +te'.'nnis';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 10);
  
  # 10 hits/page
  $file = 'test/Fireball/two_page_result';
  $query = '+Mu'.'rnau +Hinterg'.'lasbilder';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 10);
  
  ######################################################################
  $sSE = 'FolioViews';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/FolioViews/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/FolioViews/one_page_result';
  $query = 'bur'.'undi';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 400);
  
  ######################################################################
  $sSE = 'Gopher';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  no_test($sSE, $sM);
  
  ######################################################################
  $sSE = 'HotBot';
  $sM = 'Martin Thurn <MartinThurn@iname.com>';
  
  $file = 'test/HotBot/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  # 84 hits/page
  $file = 'test/HotBot/one_page_result';
  $query = '"Ch'.'ristie Abbo'.'tt"';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 100);
  
  $file = 'test/HotBot/two_page_result';
  $query = '+IS'.'I +A'.'I +netwo'.'rking';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 101);
  
  ######################################################################
  $sSE = 'HotFiles';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  $file = 'test/HotFiles/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  ######################################################################

  &eval_test('Infoseek');
  &eval_test('Infoseek::Web');
  &eval_test('Infoseek::Companies');
  &eval_test('Infoseek::News');

  ######################################################################
  $sSE = 'Livelink';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  no_test($sSE, $sM);
  
  ######################################################################
  $sSE = 'Lycos';
  $sM = 'Martin Thurn <MartinThurn@iname.com>';
  
  $file = 'test/Lycos/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Lycos/one_page_result';
  $query = '"Chri'.'stie Ab'.'bott"';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 50);
  
  $file = 'test/Lycos/multi_page_result';
  $query = 'repli'.'cation';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 100);
  
  ######################################################################
  $sSE = 'Magellan';
  $sM = 'Martin Thurn <MartinThurn@iname.com>';
  
  $file = 'test/Magellan/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Magellan/one_page_result';
  $query = 'dise'.'stablishmentarianism';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 1, 9);
  
  # 10 hits/page
  $file = 'test/Magellan/two_page_result';
  $query = '+IS'.'I +divisi'.'on';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 11);
  
  ######################################################################
  $sSE = 'Metapedia';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  $file = 'test/Metapedia/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  ######################################################################
  $sSE = 'MSIndexServer';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/MSIndexServer/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/MSIndexServer/one_page_result';
  $query = 'bur'.'undi';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99);
  
  ######################################################################
  $sSE = 'NorthernLight';
  $sM = 'unsupported';
  
  $file = 'test/NorthernLight/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/NorthernLight/one_page_result';
  $query = '+Bi'.'athlon +weltcu'.'ps +Ath'.'leten +deu'.'tschland';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 25);
  
  # 25 hits/page
  $file = 'test/NorthernLight/two_page_result';
  $query = '+LS'.'AM +IS'.'I +I'.'B';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 25);
  
  ######################################################################
  $sSE = 'Null';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/Null/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  ######################################################################
  $sSE = 'OpenDirectory';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  $file = 'test/OpenDirectory/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  ######################################################################
  $sSE = 'PLweb';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/PLweb/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/PLweb/one_page_result';
  $query = 'bur'.'undi';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99);
  
  ######################################################################
  $sSE = 'Profusion';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  $file = 'test/Profusion/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Profusion/one_page_result';
  $query = 'Astr'.'onomy';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 50);
  
  ######################################################################
  $sSE = 'Search97';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/Search97/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Search97/one_page_result';
  $query = 'bur'.'undi';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99);
  
  ######################################################################
  $sSE = 'SFgate';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  
  $file = 'test/SFgate/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/SFgate/one_page_result';
  $query = 'bur'.'undi';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99);
  
  ######################################################################
  $sSE = 'Snap';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  
  $file = 'test/Snap/zero_result'; 
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY); 
  
  $file = 'test/Snap/one_page_result'; 
  $query = 'vbt'.'hread'; 
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 99); 
  
  $file = 'test/Snap/multi_page_result'; 
  $query = 'ja'.'bba';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 100); 
  
  ######################################################################
  $sSE = 'Simple';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  no_test($sSE, $sM);
  
  ######################################################################
  $sSE = 'Verity';
  $sM = 'Paul Lindner <paul.lindner@itu.int>';
  no_test($sSE, $sM);
  
  ######################################################################

  &eval_test('WebCrawler');
  
  ######################################################################

  $sSE = 'Yahoo';
  $sM = 'Martin Thurn <MartinThurn@iname.com>';
  
  $file = 'test/Yahoo/zero_result';
  test($sSE, $sM, $file, $bogus_query, $TEST_EXACTLY);
  
  $file = 'test/Yahoo/one_page_result';
  $query = 'LSA'.'M';
  test($sSE, $sM, $file, $query, $TEST_RANGE, 2, 84);
  
  $file = 'test/Yahoo/two_page_result';
  $query = 'rep'.'lication';
  test($sSE, $sM, $file, $query, $TEST_GREATER_THAN, 100); # Yahoo seems to have 84 hits/page

  ######################################################################
  $sSE = 'ZDNet';
  $sM = 'Jim Smyser <jsmyser@bigfoot.com>';
  not_working($sSE, $sM);
  } # test_cases
  
sub main 
  {
  $pwd = `pwd`;
  chomp($pwd);
  
  $fullperl = $Config{'perlpath'};
  
  #    print "\n\nWWW::Search version " . $WWW::Search::VERSION . "\n";
  print "\nVERSION INFO:\n";
  my ($cmd) = &web_search_bin . " -V";
  print `$cmd`;
  
  if ($update_saved_files) 
    {
    print "\nUPDATING.\n\n";
    $mode = $MODE_UPDATE;
    &test_cases();
    return;
    }
  
  if ($do_internal) {
    print "\nTESTING INTERNAL PARSING.\n\t(Errors here should be reported to the WWW::Search maintainer.)\n\n";
    $mode = $MODE_INTERNAL;
    &test_cases();
    }
  
  if ($do_external) {
    print "\n\nTESTING EXTERNAL QUERIES.\n\t(Errors here suggest search-engine reformatting and should be\n\treported to the maintainer of the back-end for the search engine.)\n\n";
    $mode = $MODE_EXTERNAL;
    &test_cases();
    };
  
  print "\n";
  if ($error_count == 0) {
    print "All tests have passed.\n\n";
    } else {
      print "Some tests failed.  Please check the README file in the distribution before reporting errors (sometimes back-ends have known failures).\n";
      };
  } # main

=head2 TO DO

=item  When updating, first delete the files for the existing test results.

=cut

