# This -*- cperl -*- program writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.40 2004/09/25 21:43:16 Daddy Exp Daddy $

use inc::Module::Install;

name('WWW-Search');
version(2.474);
author('Martin Thurn <mthurn@cpan.org>');
abstract('Query web search engines and get URLs');
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
build_requires('IO::Capture::ErrorMessages' => 0);
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
&Makefile->write;

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
  if (0)
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
  use File::Spec::Functions;

  sub top_targets
    {
    use File::Temp;
    my $self = shift;
    # Use the default setting for (not) echoing commands during make:
    my $NOECHO = $self->{NOECHO};
    # Turn it off for debugging this makefile:
    # $NOECHO = '';
    # And, ignore error signals.  This is necessary because pod2test
    # carps if the file contains no test code!
    $NOECHO .= '-';
    # Figure out how to squeeze tests out of .pm files.  Assume that
    # pod2test (or pod2test.exe or pod2test.bat) is in the path.
    my $sPod2testCmd = 'pod2test %s %s';
    # There is a bug in Pod::Tests (or is it Pod::Parser).  We can not
    # read Win32 pod Unix:
    if ($^O =~ m!(solaris|linux)!)
      {
      my $sTempFname = tmpnam();
      $sPod2testCmd = 'cat %s | dos2unix > $sTempFname ; pod2test $sTempFname %s';
      # $sPod2testCmd = 'cat %s | dos2unix | pod2test > %s';
      } # if unix
    $out .= $self->SUPER::top_targets(@_);
    $out .= "\n\ntestifypods : \n";
    $out .= "\t\$(FULLPERL) -MExtUtils::Command -e rm_f t/embedded-*.t\n";
    use Data::Dumper;
    # print STDERR " + self is ", Dumper($self);
    my %hsPOD;
    foreach my $pod (
                     keys %{$self->{MAN1PODS}},
                     keys %{$self->{MAN3PODS}},
                     # Win32 has no MANPODS, so we add these:
                     keys %{$self->{PM}},
                    )
      {
      # print STDERR " +   will testifypod $pod\n";
      $hsPOD{$pod}++;
      } # foreach $pod
    foreach my $pod (keys %hsPOD)
      {
      # print STDERR " +   writing code to testifypod $pod\n";
      (my $test = $pod) =~ s/\.(pm|pod)$//;
      $test =~ s|/|-|g;
      # Same, for Win32:
      $test =~ s|\\|-|g;
      $test =~ s/^lib\W//;
      $test =~ s/\W/-/;
      $test = "embedded-$test.t";
      my $sCode = sprintf($sPod2testCmd, $pod, "t/$test");
      # print STDERR " +     code to testifypod $pod is $sCode\n";
      $out .= "\t$NOECHO $sCode\n";
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
