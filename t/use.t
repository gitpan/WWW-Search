# -*- perl -*-

use strict;
use Test;
use WWW::Search;

use vars qw( $iNum );

BEGIN 
  {
  $iNum = scalar(@WWW::Search::ENGINES_WORKING); 
  plan tests => $iNum;
  } # BEGIN

foreach my $sEngine (@WWW::Search::ENGINES_WORKING)
  {
  my $o;
  eval { $o = new WWW::Search($sEngine) };
  ok(ref($o));
  } # foreach
