# -*- perl -*-

use strict;
use Test;
use WWW::Search;

use vars qw( $iNum );

BEGIN
  {
  my $iExtraTests = 3;
  $iNum = scalar(@WWW::Search::ENGINES_WORKING);
  plan tests => $iNum + $iExtraTests;
  } # BEGIN

eval 'use WWW::Search';
# print STDERR ">>>$@<<<\n";
ok($@ eq '');
eval 'require WWW::Search::Test';
# print STDERR ">>>$@<<<\n";
ok($@ eq '');
eval 'use WWW::SearchResult';
# print STDERR ">>>$@<<<\n";
ok($@ eq '');

foreach my $sEngine (@WWW::Search::ENGINES_WORKING)
  {
  my $o;
  eval { $o = new WWW::Search($sEngine) };
  ok(ref($o));
  } # foreach

exit 0;

# Now make sure we get *some* results from *some* engine:
my $o = new WWW::Search('WebCrawler');
$o->maximum_to_retrieve(10);
$o->native_query('Ohio');
ok(5 < scalar($o->results()));
