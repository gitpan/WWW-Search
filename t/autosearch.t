# Emacs, please use -*- cperl -*- mode when editing this file

use ExtUtils::testlib;
use File::Spec::Functions;
use Test::File;
use Test::More qw(no_plan);

use strict;

my $sProg = catfile('blib', 'script', 'AutoSearch');
my $iWIN32 = ($^O =~ m!win32!i);

diag('');
file_exists_ok($sProg, "$sProg exists");
SKIP:
  {
  skip 'Can not check "executable" file flag on Win32', 1 if $iWIN32;
  file_executable_ok($sProg, "$sProg is executable");
  } # end of SKIP block
print STDERR "\r# ";
diag(`$sProg -V`);
ok(1);
exit 0;
# Special testing, not for public release:
&martin_test();

sub martin_test
  {
  my $sDir = catdir(qw( t test ));
  diag("sDir ==$sDir==");
  unlink glob(catfile($sDir, '*'));
  my $sCmd = qq{$sProg --mail mthurn\@verizon.net --emailfrom mthurn\@verizon.net $sDir --eng Ebay --qn junk --qs "Tobago flag"};
  diag("sCmd ==$sCmd==");
  my $sRes = ` $sCmd `;
  # Don't use diag() for this because it inserts '#' after every
  # newline:
  print STDERR $sRes;
  } # martin_test

__END__
