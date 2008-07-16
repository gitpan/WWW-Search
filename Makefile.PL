# This -*- cperl -*- program writes the Makefile for WWW::Search
# $Id: Makefile.PL,v 1.81 2008/07/16 00:41:13 Martin Exp $

use inc::Module::Install;

name('WWW-Search');
version(2.503);
abstract_from('lib/WWW/Search.pm');
author_from('lib/WWW/Search.pm');
license('perl');
perl_version(5.004);

install_script('Programs/AutoSearch');
install_script('Programs/WebSearch');

# These are needed for AutoSearch:
requires('Data::Dumper');
requires('Date::Manip');
recommends('Email::Send');
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
requires('LWP::UserAgent' => 2.0);
requires('LWP::MemberMixin');
requires('Net::Domain');
requires('Pod::Usage');
requires('URI');
requires('URI::Escape');
requires('User');
# These used to be needed during `make all`:
test_requires('File::Spec');
# These are needed during `make test`:
test_requires('File::Temp');
test_requires('IO::Capture::Stderr');
test_requires('Test::File');
test_requires('Test::More');
test_recommends('Test::Pod');
# I think there's a bug in Module::CoreList or something, because this
# comes up missing on some platforms:
test_requires('Test::Simple');
# For the defunct test_parsing rule, we need a version that sets
# FULLPERLRUNINST:
test_requires('ExtUtils::MM_Unix' => 1.41);

WriteAll;

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
  if (1)
    {
    $ret .= <<'PART0';
coverage :
	- cover -delete
	$(MAKE) HARNESS_PERL_SWITCHES=-MDevel::Cover test
	cover
PART0
    } # if
  if (1)
    {
    $ret .= <<'PART1';
AutoSearchblurg :: code/AutoSearch-code.pl
	$(FULLPERL) AutoSearch.PL
	$(FULLPERL) -MExtUtils::Command -e chmod 0755 $@
WebSearchfoobar :: code/WebSearch-code.pl
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

