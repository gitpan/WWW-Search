# This -*- perl -*- script writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.6 1999/07/16 18:39:16 mthurn Exp $

require 5.004;

@programs_to_install = qw( WebSearch AutoSearch );

# Allow us to suppress all program installation with the -n (library only)
# option.  This is for those that don't want to mess with the configuration
# section of this file.
use Getopt::Std;
$opt_n = undef;   # avoid -w typo waring
unless (getopts("n")) { die "Usage: $0 [-n]\n"; }
@programs_to_install = () if $opt_n;

# Ok, now it is time to really generate the Makefile
use ExtUtils::MakeMaker;
# $ExtUtils::MakeMaker::Verbose = 99;

WriteMakefile(
              'NAME' => 'WWW::Search',
              'VERSION_FROM' => 'lib/WWW/Search.pm',
              'PREREQ_PM' => {
                              'URI::Escape' => 0,
                              'HTML::Parser' => 2.16,
                              'HTML::TreeBuilder' => 0,  # release 0.51 is good
                              'LWP' => 5.30,
                             },
              'EXE_FILES' => [ @programs_to_install ],
              'clean' => { FILES => join(' ', @programs_to_install) },
              'dist' => { COMPRESS => 'gzip -fv9', SUFFIX => 'gz' },
             );

# What happens when we say 'make test'
sub MY::test 
  {
  return <<'ENDTEST';
# .PHONY: a gnu-ism
.PHONY: test

TEST_VERBOSE = 
TEST_ENGINE = 

test: all
	$(FULLPERL) -Iblib/lib test/test.pl $(TEST_VERBOSE) $(TEST_ENGINE)
test-v: all
	$(FULLPERL) -Iblib/lib test/test.pl -v $(TEST_ENGINE)

ENDTEST
} # MY::test
