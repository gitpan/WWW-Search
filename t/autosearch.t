# Emacs, please use -*- cperl -*- mode when editing this file

use File::Spec::Functions;
use ExtUtils::testlib;
use Test::More qw(no_plan);

use strict;

my $sProg = catfile('blib', 'script', 'AutoSearch');
my $iWIN32 = ($^O =~ m!win32!i);

diag('');
ok(-s $sProg, "$sProg does not exist");
ok(-f $sProg, "$sProg is not a plain file");
SKIP:
  {
  skip 'Can not check "executable" file flag on Win32', 1 if $iWIN32;
  ok(-x $sProg, "$sProg is not executable");
  } # end of SKIP block
print STDERR "\r# ";
diag(`$sProg -V`);
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
