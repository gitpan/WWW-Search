# Emacs, please use -*- perl -*- mode when editing this file

use ExtUtils::testlib;
# use Test::More qw(no_plan);
# use Test::More tests => 50;
use Test::More tests => 5;

use strict;

BEGIN { use_ok('WWW::Search') };
BEGIN { use_ok('WWW::SearchResult') };
BEGIN { use_ok('WWW::Search::Result') };
BEGIN { use_ok('WWW::Search::Test',
               qw(new_engine run_gui_test run_test skip_test count_results)) };

my @as;
eval { @as = &WWW::Search::installed_engines };
ok(0 < scalar(@as), 'No installed engines!?!');

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
