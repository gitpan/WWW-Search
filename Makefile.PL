# This -*- perl -*- script writes the Makefile for libwww-perl
# $Id: Makefile.PL,v 1.11 1997/11/04 02:07:06 johnh Exp $

#--- Configuration section ---

@programs_to_install = qw(WebSearch AutoSearch);

#--- End Configuration - You should not have to change anything below this line

require 5.002;  # LWP needs this perl version

# Allow us to suppress all program installation with the -n (library only)
# option.  This is for those that don't want to mess with the configuration
# section of this file.
use Getopt::Std;
$opt_n = undef;   # avoid -w typo waring
unless (getopts("n")) {
    die "Usage: $0 [-n]\n";
}
@programs_to_install = () if $opt_n;


# Check for non-standard modules that are used by this library.
$| = 1;
my $missing_modules = 0;

print "Checking for LWP...";
eval {
    require LWP::UserAgent;
};
if ($@) {
    print " failed\n";
    $missing_modules++;
    print <<EOT;
$@
The WWW::Search library requires the libwww-perl module.

EOT
    sleep(2);  # Don't hurry too much
} else {
    print " ok\n";
}

print <<EOT if $missing_modules;
The missing modules can be obtained from CPAN.  Visit
<URL:http://www.perl.com/CPAN/> to find a CPAN site near you.

EOT


# Ok, now it is time to really generate the Makefile
use ExtUtils::MakeMaker;

WriteMakefile(
   NAME          => 'WWW::Search',
   VERSION_FROM  => 'lib/WWW/Search.pm',
   PL_FILES      => {
                      'bin/WebSearch.PL' => 'bin/WebSearch',
                      'bin/AutoSearch.PL' => 'bin/AutoSearch',
	            },
   EXE_FILES     => [ map {"bin/$_"} @programs_to_install ],
   'clean'       => { FILES => '$(EXE_FILES)' },
   'dist'	 => { COMPRESS => 'gzip', SUFFIX => 'gz' },
);


# Some code to install programs the way we want
# sub MY::postamble {
#     my @m;
#     if (@request_aliases && grep($_ eq 'lwp-request', @programs_to_install)) {
# 	push @m, "all ::\n";
# 	push @m, "\t\$(FULLPERL) -e 'use Config; foreach (qw(@request_aliases)) {' \\\n";
# 	push @m, <<'EOT';
# 	-e 'unlink "$(INST_EXE)/$$_";' \
# 	-e 'system("$$Config{\"lns\"} lwp-request $(INST_EXE)/$$_") && die; }'
# EOT
#     }
#     join "", @m;
# }

# This is a workaround that I can't get make install to install the binaries
sub MY::postamble {
    my @m;
    foreach (@programs_to_install) {
	push @m, "install :: bin/$_\n" .
	    "\trm -f \$(INSTALLSCRIPT)/$_\n" .
	    "\tcp bin/$_ \$(INSTALLSCRIPT)\n" .
	    "\n";
    };
    return join "", @m;
}

# What happens when we say 'make test'
sub MY::test {
    q(
TEST_VERBOSE=

FORCE:

# .PHONY: a gnu-ism
.PHONY: test

TEST_VERBOSE= 

TEST_ENGINE=

test: FORCE
	$(FULLPERL) test/test.pl $(TEST_VERBOSE) $(TEST_ENGINE)

test-v:
	$(FULLPERL) test/test.pl -v $(TEST_ENGINE)

);
}


# Determine things that should *not* be installed
sub MY::libscan {
    my($self, $path) = @_;
    return '' if $path =~ m/.(pl|dtd|sgml)$/;
    return '' if $path =~ m:\bCVS/:;
    return '' if $path !~ m/\.pm$/;
    $path;
}
