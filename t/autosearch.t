# Emacs, please use -*- cperl -*- mode when editing this file

use File::Spec::Functions;
use ExtUtils::testlib;
use Test::More qw(no_plan);
# use Test::More tests => 13;

use strict;

my $sProg = catfile('blib', 'script', 'AutoSearch');
my $iWIN32 = ($^O =~ m!win32!i);

ok(-s $sProg, "$sProg does not exist");
ok(-f $sProg, "$sProg is not a plain file");
SKIP:
  {
  skip 'Can not check "executable" file flag on Win32', 1 if $iWIN32;
  ok(-x $sProg, "$sProg is not executable");
  } # end of SKIP block

exit 0;

__END__
