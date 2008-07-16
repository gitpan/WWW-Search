
# $Id: test.t,v 1.5 2008/07/16 00:41:48 Martin Exp $

# Tests for the WWW::Search::Test module

use File::Spec::Functions;
use ExtUtils::testlib;
use Test::More qw(no_plan);

use strict;

BEGIN { use_ok('WWW::Search::Test') };

my $sWebsearch1 = WWW::Search::Test::find_websearch();
ok($sWebsearch1);
# Call it again to trigger memoization code:
my $sWebsearch2 = WWW::Search::Test::find_websearch();
ok($sWebsearch2);
is($sWebsearch1, $sWebsearch2);
diag($sWebsearch1);

1;
__END__

