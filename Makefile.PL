# This -*- perl -*- script writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.12 2000/05/01 13:58:13 mthurn Exp $

require 5.004;

@programs_to_install = qw( WebSearch AutoSearch );

# Allow us to suppress all program installation with the -n (library only)
# option.  This is for those that don't want to mess with the configuration
# section of this file.
use Getopt::Std;
$opt_n = undef;   # avoid -w typo warning?
unless (getopts("n")) { die "Usage: $0 [-n]\n"; }
@programs_to_install = () if $opt_n;

# Ok, now it is time to really generate the Makefile
use ExtUtils::MakeMaker;
# $ExtUtils::MakeMaker::Verbose = 99;

WriteMakefile(
              'NAME' => 'WWW::Search',
              'VERSION_FROM' => 'lib/WWW/Search.pm',
              ($] ge '5.005') ? (
                                 'AUTHOR' => 'Martin Thurn <MartinThurn@iname.com>',
                                 'ABSTRACT' => 'Query web search engines and get URLs',
                                ) : (),
              'PREREQ_PM' => {
                              'File::Spec' => 0,
                              'URI::Escape' => 0,
                              'HTML::Parse' => 0,
                              'HTML::Parser' => 2.23,
                              'HTML::TreeBuilder' => 0,  # HTML-Tree-0.51 is good
                              'LWP' => 5.30,
                             },
              'EXE_FILES' => [ @programs_to_install ],
              'clean' => { FILES => join(' ', @programs_to_install) },
              'dist' => { COMPRESS => 'gzip -fv9', SUFFIX => 'gz' },
             );

sub MY::postamble
  {
  return '
test_parsing: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) t/test_parsing.pl $(TEST_ARGS)
';
  } # MY::postamble
