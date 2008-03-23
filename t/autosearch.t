# $Id: autosearch.t,v 1.8 2006/03/15 00:58:15 Daddy Exp $

use ExtUtils::testlib;
use File::Spec::Functions;
use Test::File;
use Test::More qw(no_plan);

use strict;

my $sProg = catfile('blib', 'script', 'AutoSearch');
my $iWIN32 = ($^O =~ m!win32!i);

file_exists_ok($sProg, "$sProg exists");
SKIP:
  {
  skip 'Can not check "executable" file flag on Win32', 1 if $iWIN32;
  file_executable_ok($sProg, "$sProg is executable");
  } # end of SKIP block
pass();
print STDERR "\n";
diag(`$sProg -V`);
pass();
exit 0;

__END__

