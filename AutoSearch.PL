# $Id: AutoSearch.PL,v 1.10 2005/02/20 02:57:47 Daddy Exp $
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
#line 4
!GROK!THIS!
$/ = "\n";
my @as = <IN>;
close IN;
# Delete 'exit 0' off top of AutoSearch-code.pl:
shift @as;
$" = "\n";
print OUT @as;
close OUT;
__END__

