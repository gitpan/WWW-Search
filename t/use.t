# Emacs, please use -*- perl -*- mode when editing this file

use ExtUtils::testlib;
use Test::More;

use strict;
use vars qw( $iNum );

BEGIN
  {
  plan tests => 4;
  } # BEGIN

eval 'use WWW::Search';
# print STDERR ">>>$@<<<\n";
ok($@ eq '', 'use WWW::Search');
eval 'require WWW::Search::Test';
# print STDERR ">>>$@<<<\n";
ok($@ eq '', 'use WWW::Search::Test');
eval 'use WWW::SearchResult';
# print STDERR ">>>$@<<<\n";
ok($@ eq '', 'use WWW::SearchResult');

my @as;
eval { @as = &WWW::Search::installed_engines };
ok(0 < scalar(@as), 'No installed engines!?!');

exit 0;

foreach my $sEngine (sort @as)
  {
  my $o;
  print STDERR " trying $sEngine...\n";
  eval { $o = new WWW::Search($sEngine) };
  ok(ref($o));
  } # foreach

# Now make sure we get *some* results from *some* engine:
my $o = new WWW::Search('WebCrawler');
$o->maximum_to_retrieve(10);
$o->native_query('Ohio');
ok(5 < scalar($o->results()));
