# $Id: WebSearch.PL,v 1.17 2004/08/21 19:45:28 Daddy Exp $
use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//i;
$codefile = "code/$file-code.pl";
open IN, "<$codefile" or die "Can't read $codefile: $!";
open OUT,">$file" or die "Can't create $file: $!";
chmod(0755, $file);
print "Converting $codefile to $file...\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'} -w
    eval 'exec perl -S \$0 "\$@"'
	if 0;

!GROK!THIS!

$/ = "\n";
my @as = <IN>;
close IN;
# Delete 'exit 0' off top of $file-code.pl:
shift @as;
$" = "\n";
print OUT @as;
close OUT;
