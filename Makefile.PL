# This -*- cperl -*- program writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.54 2006/01/08 01:38:21 Daddy Exp $

use inc::Module::Install;

name('WWW-Search');
version(2.485);
author('Martin Thurn <mthurn@cpan.org>');
abstract('Query web search engines and get URLs');
license('perl');
requires(perl => 5.004);

my @programs_to_install = qw( WebSearch AutoSearch );

# Allow us to suppress all program installation with the -n (library only)
# option.  This is for those that don't want to mess with the configuration
# section of this file.
use Getopt::Std;
my $opt_n;
unless (getopts("n")) { die "Usage: $0 [-n]\n"; }
@programs_to_install = () if $opt_n;

install_script($_) foreach @programs_to_install;
clean_files($_) foreach @programs_to_install;

# These are needed for AutoSearch:
requires('Data::Dumper');
requires('Date::Manip');
recommends('Email::Send');
recommends('Email::Send::SMTP::Auth');
recommends('Email::MIME');
recommends('Email::MIME::Creator');
requires('File::Copy');
requires('Getopt::Long' => 2.24);
requires('POSIX');
# These are needed for WebSearch:
requires('Getopt::Long' => 2.24);
# These are needed for WWW::Search base module:
requires('File::Basename');
requires('File::Find');
requires('File::Spec');
requires('HTML::Parser' => 2.23);
requires('HTML::TreeBuilder');  # HTML-Tree-0.51 is good
build_requires('IO::Capture::Stderr' => 0);
requires('LWP::UserAgent' => 2.0);
requires('Net::Domain');
requires('Pod::Usage');
requires('URI');
requires('URI::Escape');
requires('User');
# These are needed during `make all`:
build_requires('File::Spec');
# These are needed during `make test`:
build_requires('File::Temp');
build_requires('Pod::Tests' => 0.12);
build_requires('Test::Inline' => 0.16);
build_requires('Test::File');
build_requires('Test::More');
build_requires('Test::Pod');
# I think there's a bug in Module::CoreList or something, because this
# comes up missing on some platforms:
build_requires('Test::Simple');
# For the defunct test_parsing rule, we need a version that sets
# FULLPERLRUNINST:
build_requires('ExtUtils::MM_Unix' => 1.41);

check_nmake();      # check and download nmake.exe for Win32
&WriteAll;

sub MY::preamble
  {
  # This does not work because MakeMaker apparently does not have a
  # preamble method.
  return '

AutoSearch :: FORCE
	/bin/rm -f AutoSearch

';
  } # MY::preamble


sub MY::postamble
  {
  my $ret = <<'PART0';
coverage :
	cover -delete
	$(MAKE) HARNESS_PERL_SWITCHES=-MDevel::Cover coverage_slave
coverage_slave : test
	cover
PART0
  if (1)
    {
    $ret .= <<'PART1';
AutoSearch :: code/AutoSearch-code.pl
	$(FULLPERL) -MExtUtils::Command -e chmod 0755 AutoSearch.PL
	$(FULLPERL) AutoSearch.PL
	$(FULLPERL) -MExtUtils::Command -e chmod 0755 $@
WebSearch :: code/WebSearch-code.pl
	$(FULLPERL) -MExtUtils::Command -e chmod 0755 WebSearch.PL
	$(FULLPERL) WebSearch.PL
	$(FULLPERL) -MExtUtils::Command -e chmod 0755 $@

PART1
    } # if
  if (0)
    {
    $ret .= <<'PART2';
test_parsing : pure_all
	$(FULLPERLRUNINST) t/test_parsing.pl $(TEST_ARGS)

PART2
    } # if
  if (1)
    {
    $ret .= <<'PART3';
tags:
	cat MANIFEST | etags -

PART3
    } # if
  return $ret;
  } # MY::postamble

# The following was added for Test::Inline handling.  Derived from
# `perldoc Test::Inline::Tutoral`.

  {
  package MY;
  use Config;
  use constant DEBUG_INLINE => 0;

  sub pod2test_command
    {
    my $sNoEcho = shift;
    my $sPodFname = shift;
    my $sTestFname = shift;
    # Figure out how to squeeze tests out of .pm files.  Assume that
    # pod2test (or pod2test.exe or pod2test.bat) is in the path.
    # (This should be a safe assumption, since Test::Inline is one of
    # our Prereqs)
    my $sPod2testCmd = qq{\t$sNoEcho pod2test $sPodFname $sTestFname\n};
    # There is a bug in Pod::Tests (or is it Pod::Parser).  We can not
    # read MSWin32 pod on Unix:
    if ($^O =~ m!(solaris|linux|darwin)!)
      {
      my $sPerl = $Config{'perlpath'};
      $sPod2testCmd = <<"CMD";
\t$sNoEcho $sPerl -pe"tr/\\r//d" < $sPodFname | pod2test > $sTestFname
\t$sNoEcho $sPerl -e"unlink '$sTestFname' unless -s '$sTestFname'"
CMD
      # DEBUG_INLINE && print STDERR " DDD here are the keys in Config: ", join(', ', keys %Config), "\n";
      # DEBUG_INLINE && print STDERR " DDD here is config_vars(perlpath) =", config_vars('perlpath'), "=\n";
      } # if unix
    return $sPod2testCmd;
    } # pod2test_command

  sub top_targets
    {
    my $self = shift;
    # Use the default setting for (not) echoing commands during make:
    my $NOECHO = $self->{NOECHO};
    # Turn it off for debugging this makefile:
    $NOECHO = '';
    # And, ignore error signals.  This is necessary because pod2test
    # carps if the file contains no test code!
    $NOECHO .= '-';
    $out .= $self->SUPER::top_targets(@_);
    $out .= "\n\ntestifypods : \n";
    $out .= "\t\$(FULLPERL) -MExtUtils::Command -e rm_f t/embedded-*.t\n";
    # use Data::Dumper;
    # print STDERR " + self is ", Dumper($self);
    my %hsPOD;
    foreach my $pod (
                     keys %{$self->{MAN1PODS}},
                     keys %{$self->{MAN3PODS}},
                     # Win32 has no MANPODS, so we add these
                     # brute-force-like:
                     keys %{$self->{PM}},
                    )
      {
      DEBUG_INLINE && print STDERR " +   will testifypod $pod\n";
      $hsPOD{$pod}++;
      } # foreach $pod
    foreach my $pod (keys %hsPOD)
      {
      DEBUG_INLINE && print STDERR " +   writing code to testifypod $pod\n";
      (my $test = $pod) =~ s/\.(pm|pod)$//;
      $test =~ s|/|-|g;
      # Same, for Win32:
      $test =~ s|\\|-|g;
      $test =~ s/^lib\W//;
      $test =~ s/\W/-/;
      $test = "embedded-$test.t";
      my $sCode = pod2test_command($NOECHO, $pod, "t/$test");
      DEBUG_INLINE && print STDERR " +     code to testifypod $pod is =$sCode=\n";
      $out .= $sCode;
      } # foreach
    return $out;
    } # MY::top_targets

  sub test
    {
    my $self = shift;
    my $out = $self->SUPER::test(@_);
    # Insert our target as a prerequisite for the main test goal:
    $out =~ s!^(test\s*::?\s+)(.*)!$1 pure_all testifypods $2!mg;
    return $out;
    } # MY::test

  } # end of package MY block

__END__

