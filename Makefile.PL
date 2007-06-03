# This -*- cperl -*- program writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.68 2007/05/09 22:02:43 Daddy Exp $

use inc::Module::Install;

name('WWW-Search');
version(2.494);
abstract_from('lib/WWW/Search.pm');
author_from('lib/WWW/Search.pm');
license('perl');
perl_version(5.004);

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
# These are needed for WWW::Search base module and sub-modules:
requires('CGI');
requires('File::Basename');
requires('File::Find');
requires('File::Spec');
requires('HTML::Parser' => 2.23);
requires('HTML::TreeBuilder');  # HTML-Tree-0.51 is good
test_requires('IO::Capture::ErrorMessages');
requires('LWP::UserAgent' => 2.0);
requires('LWP::MemberMixin');
requires('Net::Domain');
requires('Pod::Usage');
requires('URI');
requires('URI::Escape');
requires('User');
# These used to be needed during `make all`:
build_requires('File::Spec');
# These are needed during `make test`:
build_requires('File::Temp');
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
	$(FULLPERL) AutoSearch.PL
	$(FULLPERL) -MExtUtils::Command -e chmod 0755 $@
WebSearch :: code/WebSearch-code.pl
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

__END__

