# Emacs, please use -*- cperl -*- mode when editing this file

use ExtUtils::testlib;
# use Test::More qw(no_plan);
use Test::More tests => 13;

use strict;

BEGIN { use_ok('WWW::Search') };
BEGIN { use_ok('WWW::SearchResult') };
BEGIN { use_ok('WWW::Search::Result') };
BEGIN { use_ok('WWW::Search::Test',
               qw(new_engine run_gui_test run_test skip_test count_results)) };

my @as;
eval { @as = &WWW::Search::installed_engines };
ok(0 < scalar(@as), 'No installed engines!?!');

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

