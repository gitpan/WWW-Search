# Emacs, please use -*- cperl -*- mode when editing this file

use ExtUtils::testlib;
use Test::More no_plan;

use IO::Capture::ErrorMessages;
my $oICE =  IO::Capture::ErrorMessages->new;

use strict;

BEGIN { use_ok('WWW::Search') };
BEGIN { use_ok('WWW::SearchResult') };
BEGIN { use_ok('WWW::Search::Result') };
BEGIN { use_ok('WWW::Search::Test',
               qw(new_engine run_gui_test run_test skip_test count_results)) };

my @as;
eval { @as = &WWW::Search::installed_engines };
ok(0 < scalar(@as), 'any installed engines');
diag('FYI the following backends are already installed (including ones in this distribution): '. join(', ', sort @as));

# Make sure an undef query does not die;
my $o1 = new WWW::Search; # NO BACKEND SPECIFIED
ok(ref $o1);
my @ao = $o1->results();
ok(ref $o1->response);
ok($o1->response->is_error);
ok(scalar(@ao) == 0);
# Make sure an empty query does not die;
my $o2 = new WWW::Search; # NO BACKEND SPECIFIED
ok(ref $o2);
$o2->native_query(''); # EMPTY STRING
my @ao2 = $o2->results();
ok(ref $o2->response);
ok($o2->response->is_error);
ok(scalar(@ao2) == 0);
# Tests for approx_result_count:
is($o2->approximate_result_count(3), 3);
is($o2->approximate_result_count(undef), 3);
is($o2->approximate_result_count(''), 3);
is($o2->approximate_result_count(0), 0);
is($o2->approximate_result_count(2), 2);
is($o2->approximate_hit_count(undef), 2);
is($o2->approximate_hit_count(-1), 2);
# Test for what happens when a backend is not installed:
my $o3;
eval { $o3 = new WWW::Search('No_Such_Backend') };
like($@, qr{(?i:unknown search engine backend)});
# Use a backend twice (just to exercise the code in Search.pm):
my $o4 = new WWW::Search('Null::Empty');
my $o5 = new WWW::Search('Null::Empty');
# Test the version() function:
$o5 = new WWW::Search('Null::NoVersion');
is($o5->version, $WWW::Search::VERSION);
is($o5->maintainer, $WWW::Search::MAINTAINER);
# Exercise / test the cookie_jar() function:
$o4->cookie_jar('t/cookies.txt');
my $oCookies = new HTTP::Cookies;
$o5->cookie_jar($oCookies);
$oICE->start;
eval { $o2->cookie_jar($o4) };
$oICE->stop;
$oCookies = $o4->cookie_jar;

exit 0;

foreach my $sEngine (@as)
  {
  my $o;
  # diag(qq{trying $sEngine});
  eval { $o = new WWW::Search($sEngine) };
  ok(ref($o), qq{loaded WWW::Search::$sEngine});
  } # foreach

exit 0;

# Now make sure we get *some* results from *some* engine:
my $o = new WWW::Search('WebCrawler');
$o->maximum_to_retrieve(10);
$o->native_query('Ohio');
ok(5 < scalar($o->results()));

__END__
