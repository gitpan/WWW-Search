# This -*- cperl -*- program writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.32 2003-09-16 21:54:34-04 kingpin Exp kingpin $

require 5.004;

@programs_to_install = qw( WebSearch AutoSearch );

# Allow us to suppress all program installation with the -n (library only)
# option.  This is for those that don't want to mess with the configuration
# section of this file.
use Getopt::Std;
my $opt_n;
unless (getopts("n")) { die "Usage: $0 [-n]\n"; }
@programs_to_install = () if $opt_n;

# Ok, now it is time to really generate the Makefile
use ExtUtils::MakeMaker;
# $ExtUtils::MakeMaker::Verbose = 99;

WriteMakefile(
              'NAME' => 'WWW::Search',
              'VERSION' => 2.43,

              ($] ge '5.005') ? (
                                 'AUTHOR' => 'Martin Thurn <mthurn@cpan.org>',
                                 'ABSTRACT' => 'Query web search engines and get URLs',
                                ) : (),
              'EXE_FILES' => [ @programs_to_install ],
              'PREREQ_PM' => {
                              # For the defunct test_parsing rule, we
                              # need a version that sets
                              # FULLPERLRUNINST:
                              # 'ExtUtils::MM_Unix' => 1.41,

                              # These are needed for AutoSearch:
                              'Getopt::Long' => 2.24,
                              'POSIX' => 0,
                              'MIME::Lite' => 0,  # only needed for
                                                  # the --mail option

                              # These are needed _only_ during `make
                              # test`:
                              'Test::Inline' => 0,
                              'Test::More' => 0,
                              # These are needed for WWW::Search base
                              # module:
                              'File::Basename' => 0,
                              'File::Find' => 0,
                              'File::Spec' => 0,
                              'HTML::Parser' => 2.23,
                              'HTML::TreeBuilder' => 0,  # HTML-Tree-0.51 is good
                              'LWP::UserAgent' => 2.0,
                              'Net::Domain' => 0,
                              'URI' => 0,
                              'URI::Escape' => 0,
                              'User' => 0,
                             },
              'clean' => { FILES => join(' ', @programs_to_install) },
             );

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
  my $ret = '';
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
    my $self = shift;
    # Use the default setting for (not) echoing commands during make:
    my $NOECHO = $self->{NOECHO};
    # Turn it off for debugging this makefile:
    # $NOECHO = '';
    # And, ignore error signals.  This is necessary because pod2test
    # carps if the file contains no test code!
    $NOECHO .= '-';
    # Assume that pod2test was installed into the same place as perl
    # itself:
    my $POD2TEST = '$(INSTALLBIN)/pod2test';
    # But on Windows, it MUST be in the path:
    $POD2TEST = 'pod2test' if $^O =~ m!win32!i;
    my $out = "POD2TEST_EXE = $POD2TEST\n";
    $out .= $self->SUPER::top_targets(@_);
    $out .= "\n\ntestifypods : \n";
    $out .= "\t\$(FULLPERL) -MExtUtils::Command -e rm_f t/embedded-*.t\n";
    use Data::Dumper;
    # print STDERR " + self is ", Dumper($self);
    my %hsPOD;
    foreach my $pod (keys %{$self->{MAN1PODS}},
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
      $test =~ s/^lib\W//;
      $test =~ s/\W/-/;
      $test = "embedded-$test.t";
      my $sCode = "\$(POD2TEST_EXE) $pod t/$test";
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
