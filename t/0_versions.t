# $Id: 0_versions.t,v 1.3 2004/07/01 02:25:49 Daddy Exp $

use strict;
use Test::More tests => 1;

# Create a list of modules we're interested in:
my @asModule = qw( File::Find File::Spec Getopt::Long HTML::Parser HTML::TreeBuilder HTTP::Cookies LWP::UserAgent MIME::Lite Net::Domain URI User );

# Extract the version number from each module:
my %hsvVersion;
foreach my $sModule (@asModule)
  {
  eval " require $sModule; ";
  unless($@)
    {
    no strict 'refs';
    $hsvVersion{$sModule} = ${$sModule .'::VERSION'} || "unknown";
    } # unless
  } # foreach

# Also look up the version number of perl itself:
eval ' use Config; $hsvVersion{perl} = $Config{version} ';  # Should never fail
if($@)
  {
  $hsvVersion{perl} = $];
  } # if

# Print on STDERR details of installed modules:
diag(sprintf("\r#  %-30s %s\n", 'Module', 'Version'));
foreach my $sModule (sort keys %hsvVersion)
  {
  $hsvVersion{$sModule} = 'Not Installed' unless(defined($hsvVersion{$sModule}));
  diag(sprintf(" %-30s %s\n", $sModule, $hsvVersion{$sModule}));
  } # foreach

# Make sure this file passes at least one test:
ok(1);
exit 0;
__END__