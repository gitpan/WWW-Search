# -*- perl -*-

use strict;
use Test;
use WWW::Search;

use vars qw( $iNum );

BEGIN 
  {
  my $iExtraTests = 1;
  $iNum = scalar(@WWW::Search::ENGINES_WORKING); 
  plan tests => $iNum + $iExtraTests;
  } # BEGIN

foreach my $sEngine (@WWW::Search::ENGINES_WORKING)
  {
  my $o;
  eval { $o = new WWW::Search($sEngine) };
  ok(ref($o));
  } # foreach

# Now make sure we get *some* results from *some* engine:
my $o = new WWW::Search('WebCrawler');
$o->maximum_to_retrieve(10);
$o->native_query('cpan+perl');
ok(5 < scalar($o->results()));
