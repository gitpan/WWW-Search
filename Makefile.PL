# This -*- perl -*- script writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.23 2002/03/22 14:58:26 mthurn Exp mthurn $

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
              'VERSION' => 2.31,

              ($] ge '5.005') ? (
                                 'AUTHOR' => 'Martin Thurn <mthurn@tasc.com>',
                                 'ABSTRACT' => 'Query web search engines and get URLs',
                                ) : (),
              'EXE_FILES' => [ @programs_to_install ],
              'PREREQ_PM' => {
                              'File::Spec' => 0,
                              'HTML::Parse' => 0,
                              'HTML::Parser' => 2.23,
                              'HTML::TreeBuilder' => 0,  # HTML-Tree-0.51 is good
                              'LWP' => 5.53,
                              'MIME::Lite' => 0,  # only needed for AutoSearch's --mail option
                              'Net::Domain' => 0,
                              'URI' => 0,
                              'URI::Escape' => 0,
                              'User' => 0,
                             },
              'clean' => { FILES => join(' ', @programs_to_install) },
             );

sub MY::postamble
  {
  return '
test_parsing: pure_all
	PERL_DL_NONLAZY=1 $(FULLPERL) -I$(INST_ARCHLIB) -I$(INST_LIB) -I$(PERL_ARCHLIB) -I$(PERL_LIB) t/test_parsing.pl $(TEST_ARGS)

tags:
	cat MANIFEST | etags -
';
  } # MY::postamble
