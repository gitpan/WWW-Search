
=head1 NAME

Test - utilities to aid in testing WWW::Search backends

=head1 SYNOPSIS

  $oTest = new WWW::Search::Test('HotBot,Yahoo,Excite');
  $oTest->test('HotBot', 'Kingpin', 'one', $sQuery, $TEST_RANGE, 1, 10);

=head1 DESCRIPTION

See file test.pl in the WWW-Search-HotBot distribution for a detailed
"real-world" example.

=head1 METHODS AND FUNCTIONS

=cut

package WWW::Search::Test;

use Carp;
use File::Spec;

use strict;

use vars qw( $MODE_DUMMY $MODE_INTERNAL $MODE_EXTERNAL $MODE_UPDATE );
use vars qw( $TEST_DUMMY $TEST_EXACTLY $TEST_BY_COUNTING $TEST_GREATER_THAN $TEST_RANGE );
use vars qw( $iTest $oSearch $sEngine );

require Exporter;
use vars qw( @EXPORT @EXPORT_OK @ISA );
@EXPORT = qw( eval_test test
              no_test not_working not_working_with_tests not_working_and_abandoned
              $MODE_DUMMY $MODE_INTERNAL $MODE_EXTERNAL $MODE_UPDATE
              $TEST_DUMMY $TEST_EXACTLY $TEST_BY_COUNTING $TEST_GREATER_THAN $TEST_RANGE
              new_engine run_test run_gui_test skip_test
            );
@EXPORT_OK = qw( );
@ISA = qw( Exporter );

use Config;
use Cwd;
use File::Path;

use vars qw( $VERSION $bogus_query );

$VERSION = '2.17';
$bogus_query = "Bogus" . $$ . "NoSuchWord" . time;

($MODE_DUMMY, $MODE_INTERNAL, $MODE_EXTERNAL, $MODE_UPDATE) = qw(dummy internal external update);
($TEST_DUMMY, $TEST_EXACTLY, $TEST_BY_COUNTING, $TEST_GREATER_THAN, $TEST_RANGE) = (1..10);

# At the time this module is loaded, try to find a working WebSearch:
my @as = split(/\s/, eval{`WebSearch --VERSION`});
my $websearch = shift @as;
# Try local directory, in case . is not in the path:
(-f './WebSearch') && (@as = split(/\s/, eval{`./WebSearch --VERSION`}));
$websearch ||= shift @as;
$websearch ||= 'not in the path';
undef $websearch unless $websearch =~ m/WebSearch/;
# print STDERR "in WWW::Search::Test, websearch is $websearch\n";

=head2 new

Create a new WWW::Search::Test object.
All arguments are strings, names of backends that this object will be able to test.
If no arguments are given, will be able to test all backends.

=cut

sub new
  {
  my $class = shift;
  my $sEngines = join(',', '', @_, '');

  return bless {
                debug => 0,
                engines => $sEngines,
                error_count => 0,
                mode => $MODE_DUMMY,
                verbose => 0,
                websearch => $websearch,
               }, $class;
  } # new


=head2 mode

Set / get the test mode of this object.
If an argument is given, sets the mode to that value.
Returns the current (or newly set) value.

There are three test modes available.  They are:

  $MODE_INTERNAL: parse URLs out of saved pages (as a sanity check or regression test);
  $MODE_EXTERNAL: send the query to the search engine "live", parse the results, and compare them to the previously saved results;
and
  $MODE_UPDATE: send the query to the search engine "live", parse the results, and save them for future testing.

=cut

sub mode
  {
  my $self = shift;
  my $new_mode = shift;
  if ($new_mode)
    {
    $self->{'mode'} = $new_mode;
    }
  return $self->{'mode'};
  } # mode

=head2 relevant_test

Given the name of a backend,
returns true if this Test object is able to test that backend.

=cut

sub relevant_test
  {
  my $self = shift;
  return 1 if ($self->{engines} eq ',,');
  my $e = ','.shift().',';
  # print STDERR " + relevant_test($e|", $self->{engines}, ")\n";
  return ($self->{engines} =~ m/$e/);
  } # relevant_test


=head2 eval_test

Given the name of a backend,
grabs the $TEST_CASES variable from that backend and evaluates it.

=cut

sub eval_test
  {
  my $self = shift;
  my $sSE = shift;
  return unless $self->relevant_test($sSE);
  my $o = new WWW::Search($sSE);
  my $iVersion = $o->version;
  my $code = $o->test_cases;
  $code ||= '';
  unless ($code ne '')
    {
    print "  $sSE version $iVersion contains no TEST_CASES\n";
    $self->{error_count}++;
    }
  # print STDERR " BEFORE SUBST: $code\n";
  $code =~ s!&test\(!\$self->test\(!g;
  $code =~ s/&no_test\(/\$self->no_test\(/g;
  $code =~ s/&not_working\(/\$self->not_working\(/g;
  $code =~ s/&not_working_and_abandoned\(/\$self->not_working_and_abandoned\(/g;
  $code =~ s/&not_working_with_tests\(/\$self->not_working_with_tests\(/g;
  # print STDERR " AFTER SUBST: $code\n";
  print "\n";  # put a little space between each engine's results
  eval $code; 
  warn $@ if $@;
  } # eval_test


=head2 test

Run test(s) for a backend.
Arguments are, in order: 
name of a backend to test (string, required);
name of backend maintainer (string, if undef $backend::MAINTAINER will be used);
filename for results storage/comparison (string, required);
query to be sent to backend (string, required);
test method (required, one of the following).

Several test methods are possible:

  $TEST_EXACTLY: list of URLs must match exactly (line for line, in order);
  $TEST_BY_COUNTING: test passes if number of resulting URLs is equal;
  $TEST_GREATER_THAN: test passes if we get more than N result URLs;
and
  $TEST_RANGE: like $TEST_GREATER_THAN but constrained on both ends.

=cut

sub test
  {
  my $self = shift;
  my $sSE = shift;
  my $sM = shift;
  my $file = shift;
  my $query = shift;
  my $test_method = shift;
  print STDERR " + test($sSE,$sM,$file,$query,$test_method)\n" if $self->{debug};
  my ($low_end, $high_end) = @_;
  $low_end ||= 0;
  $high_end ||= 0;
  my $sExpected = $low_end;
  if ($test_method == $TEST_GREATER_THAN)
    {
    $low_end++;
    $sExpected = "$low_end..";
    }
  if (0 < $high_end)
    {
    $sExpected = "$low_end..$high_end";
    }
  
  return if (!$self->relevant_test($sSE));
  
  print "  trial $file (", $self->{'mode'}, ")\n";
  if (($self->{'mode'} eq $MODE_INTERNAL) && ($query =~ m/$bogus_query/))
    {
    print "  skipping test on this platform.\n";
    return;
    } # if

  my $pwd = File::Spec->curdir();
  my @asSE = split(/::/, $sSE);
  my $path = File::Spec->catdir($pwd, 'Test-Pages', @asSE);
  mkpath $path;
  if ($self->{'mode'} eq $MODE_UPDATE)
    {
    # Delete all existing test result files for this Engine:
    opendir DIR, $path;
    foreach my $afile (readdir DIR)
      {
      unlink File::Spec->catfile($path, $afile) if $afile =~ m/^$file/;
      } # foreach
    closedir DIR;
    } # if MODE_UPDATE
  # Look at the filename argument we got:
  my ($v,$d,$f) = File::Spec->splitpath($file);
  # If it contains no path element (file name only):
  if ($d eq '')
    {
    # Prepend path onto file:
    $file = File::Spec->catfile($path, $file);
    } # if
  my $o = new WWW::Search($sSE);
  my $version = $o->version;
  print "  ($sSE $version, $sM)\n";
  print STDERR "  expect to find results in $file\n" if $self->{debug};
  my %src = (
             $MODE_INTERNAL => "--option search_from_file=$file",
             $MODE_EXTERNAL => '',
             $MODE_UPDATE => "--option search_to_file=$file",
            );
  # --max 209 added by Martin Thurn 1999-09-27.  We never want to
  # fetch more than three pages, if we can at all help it (or do we?)
  my $websearch = $self->{websearch};
  $websearch ||= File::Spec->catfile($pwd, 'blib', 'script', 'WebSearch');
  my $cmd = $Config{'perlpath'} . " -MExtUtils::testlib $websearch ";
  $cmd .= $self->{debug} ? '--debug '.$self->{debug} : '';
  $cmd .= " --max 209 --engine $sSE ". $src{$self->{'mode'}} ." -- $query";
  print "  $cmd\n" if ($self->{verbose} || $self->{debug});
  open(TRIALSTREAM, "$cmd|") || die "$0: cannot run test ($!)\n";
  open(TRIALFILE, ">$file.trial") || die "$0: cannot open $file.trial for writing ($!)\n";
  open(OUTFILE, ">$file.out") || die "$0: cannot open $file.out for writing ($!)\n" if ($self->{'mode'} eq $MODE_UPDATE);
  my $iActual = 0;
  while (<TRIALSTREAM>) 
    {
    print TRIALFILE $_;
    $iActual++;
    print OUTFILE $_ if ($self->{'mode'} eq $MODE_UPDATE);
    }
  close TRIALSTREAM;
  close TRIALFILE;
  if ($self->{'mode'} eq $MODE_UPDATE)
    {
    close OUTFILE;
    if (open TS, ">$file.README")
      {
      print TS "This set of test-result pages was created on ", scalar(localtime(time)), "\n";
      close TS;
      } # if
    my $iPageCount = &wc_l($file);
    my $iURLCount = &wc_l("$file.out");
    print "  $query --> $iURLCount urls (should be $sExpected) on $iPageCount pages\n";
    return;
    } # if

  if (-f "$file.out") 
    {
    my ($e, $sMsg) = (0, '');
    if ($test_method == $TEST_GREATER_THAN) 
      {
      if ($iActual <= $low_end)
        {
        $sMsg .= "expected more than $low_end, but got $iActual; ";
        $e = 1;
        }
      } # TEST_GREATER_THAN
    elsif ($test_method == $TEST_RANGE) 
      {
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
      $self->{error_count}++;
      }
    else 
      {
      print "INTERNAL ERROR $query --> e is $e.\n";
      $self->{error_count}++;
      }
    } 
  else 
    {
    print "NO SAVED OUTPUT, can not evaluate test results.\n";
    $self->{error_count}++;
    }
  } # test

=head2 no_test

Prints a message stating that this backend does not have a test suite.
Takes two arguments, the backend name and the name of the maintainer.

=cut

sub no_test
  {
  my $self = shift;
  my ($engine, $maint) = @_;
  return unless ($self->relevant_test($engine));
  print <<"NONE";
  trial none ($engine)
  This search engine does not have any tests,
  but report problems with it to $maint.
NONE
  } # no_test

=head2 not_working

Prints a message stating that this backend is known to be broken.
Takes two arguments, the backend name and the name of the maintainer.

=cut

sub not_working
  {
  my $self = shift;
  my ($engine, $maint) = @_;
  return unless ($self->relevant_test($engine));
  print <<"BROKEN";
  trial none ($engine)
  This search engine is known to be non-functional.  
  You are encouraged to investigate the problem and email its maintainer, 
  $maint.
BROKEN
  } # not_working

=head2 not_working_with_tests

Prints a message stating that this backend is known to be broken
even though it has a test suite.
Takes two arguments, the backend name and the name of the maintainer.

=cut

sub not_working_with_tests
  {
  my $self = shift;
  my ($engine, $maint) = @_;
  return if (!$self->relevant_test($engine));
  print <<"KNOWNFAILURE";
  trial none ($engine)
  Test cases for this search engine are known to fail.
  You are encouraged to investigate the problem and email its maintainer,
  $maint.
KNOWNFAILURE
  } # not_working_with_tests 

=head2 not_working_and_abandoned

Prints a message stating that this backend is known to be broken
and is not being actively maintained.
Takes two arguments, the backend name and the name of the maintainer.

=cut

sub not_working_and_abandonded
  {
  my $self = shift;
  my ($engine, $maint) = @_;
  return if (!$self->relevant_test($engine));
  print <<"ADOPT";
  trial none ($engine)
  This search engine is known to be non-functional.
  You are encouraged to adopt it from its last known maintainer,
  $maint.
ADOPT
  } # not_working_and_abandonded

=head2 reset_error_count

Reset the counter of errors to zero.
You probably want to call this before each call to test() or eval_test().

=cut

sub reset_error_count
  {
  my $self = shift;
  $self->{error_count} = 0;
  } # reset_error_count

=head2 wc_l (private, not a method)

Given a filename, count the number of lines of text contained
within the file.  
(I.e. simulate running UNIX command C<wc -l> on a file)

=cut

sub wc_l
  {
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

=head2 diff (private, not a method)

Given two files, returns TRUE if contents are line-by-line
different, or FALSE if contents are line-by-line same.
(I.e. like the UNIX command diff, but just reports true or false)

=cut

sub diff
  {
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


=head2 Shortcuts for running backend tests

WWW::Search::Test keeps its own count of test numbers,
so if you want to mix-and-match these functions with your own tests,
use the $WWW::Search::Test::iTest counter.

=head2 new_engine

One argument: the name of a backend suitable to be passed to WWW::Search::new().
Prints 'ok' or 'not ok' and the test number.
Creates a WWW::Search object internally,
to be used for all subsequent calls to run_test and run_gui_test (see below).

=cut

sub new_engine
  {
  $iTest++;
  $sEngine = shift;
  $oSearch = new WWW::Search($sEngine);
  print ref($oSearch) ? '' : 'not ';
  print "ok $iTest\n";
  } # new_engine

=head2 run_test

=head2 run_gui_test

Three arguments: a query string, NOT escaped; a minimum number of expected results; and
a maximum number of expected results.
Optional fourth argument: integer value to be used as the search_debug.

If the minimum is undef, assumes zero.
If the maximum is undef, does not check.

Prints 'ok' or 'not ok' and the test number.

=cut

sub run_test
  {
  return &run_our_test('normal', @_);
  } # run_test

sub run_gui_test
  {
  return &run_our_test('gui', @_);
  } # run_gui_test

sub run_our_test
  {
  my ($sType, $sQuery, $iMin, $iMax, $iDebug, $iPrintResults) = @_;
  $iDebug ||= 0;
  $iPrintResults ||= 0;
  carp ' --- min/max values out of order?' if defined($iMin) && defined($iMax) && ($iMax < $iMin);
  my $sExpect;
  if (! defined($iMax))
    {
    $sExpect = "more than $iMin";
    }
  elsif (! defined($iMin))
    {
    $sExpect = "fewer than $iMax";
    }
  else
    {
    $sExpect = "$iMin..$iMax";
    }
  $iMin ||= 0;
  if ($iMin == $iMax)
    {
    # The caller expects an exact result set.  Do not limit how many
    # results are returned.
    $oSearch->maximum_to_retrieve(99999);
    }
  else
    {
    if (defined $iMax)
      {
      $oSearch->maximum_to_retrieve($iMax + 1);
      }
    else
      {
      $oSearch->maximum_to_retrieve($iMin + 1);
      $iMax = 999999;
      }
    }
  $iTest++;
  $sQuery = WWW::Search::escape_query($sQuery);
  # print STDERR " + in WWW::Search::Test::run_our_test, iDebug = $iDebug\n";
  if ($sType eq 'gui')
    {
    $oSearch->gui_query($sQuery,
                          { 'search_debug' => $iDebug, },
                       );
    }
  else
    {
    $oSearch->native_query($sQuery,
                             { 'search_debug' => $iDebug, },
                          );
    }
  my @aoResults = $oSearch->results();
  if ($iPrintResults)
    {
    $, = "\n";
    print map { $_->url .' == '. $_->description } @aoResults;
    print "\n";
    } # if
  my $iResults = scalar(@aoResults);
  if (($iResults < $iMin) || ($iMax < $iResults))
    {
    print STDERR " --- got $iResults results for $sType $sEngine query '$sQuery', but expected $sExpect\n";
    print STDOUT 'not ';
    } # if
  print STDOUT "ok $iTest\n";
  } # run_test

=head2 skip_test

You can call this function instead of run_test() or run_gui_test()
if the current test must be skipped for any reason.

=cut

sub skip_test
  {
  $iTest++;
  print STDOUT "skip $iTest\n";
  } # skip_test

1;

__END__
