use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
      if ($Config{'osname'} eq 'VMS' or
          $Config{'osname'} eq 'OS2');  # "case-forgiving"
$debug = (`hostname` =~ /^dash.isi.edu/);   # development hack
open OUT,">$file" or die "Can't create $file: $!";
chmod(0755, $file);
print "Extracting $file (with variable substitutions)\n";

print OUT <<"!GROK!THIS!";
$Config{'startperl'} -w
    eval 'exec perl -S \$0 "\$@"'
	if 0;

!GROK!THIS!

print OUT <<'!NO!SUBS!';

#
# WebSearch.PL
# Copyright (C) 1996-1997 by USC/ISI
# $Id: WebSearch.PL,v 1.27 1997/10/24 17:13:07 johnh Exp $
#
# Complete copyright notice follows below.
#


sub usage {
    print STDERR <<END;
usage: $0 [-e SearchEngine] [-o option] [-o option...] [-vr] query

Make a query to a web search engine, showing the primary URLs which match.

END
    exit 1;
}


=head1 NAME

WebSearch - a web-searching application demonstrating WWW::Search


=head1 SYNOPSIS

B<WebSearch [-e SearchEngine] [-o option] [-o option...] [-va] query>


=head1 DESCRIPTION

This program is provides a command-line interface to web search engines,
listing all URLs found for a given query.  This program also provides
a simple demonstration of the WWW::Search Perl library for web searches.

The program current supports a number of search engines;
see L<WWW::Search> for a list.

A more sophisticated client is L<AutoSearch>
which maintains a change list of found objects.

For examples and hints about searches,
see L<AutoSearch>.


=head1 OPTIONS

=over 8

=item C<-e>

Specify the search engine.
Capitalization matters.
See L<WWW::Search> for a complete list of supported engines.

=item C<-m> max_count

Specify the maximum number of hits to retrieve.

=item C<-o>

Specify a search-engine option.

=item C<-v>

Verbose mode.  Enumerate the returned URLs.

=item C<-a>

Return all URLs.  Some different URLs may refer to the same object.

=item C<-r>

Return the raw entries (HTML).

=back


=head1 SEE ALSO

For the library, see L<WWW::Search>.

For a more sophisticated client, see L<AutoSearch>.


=head1 AUTHOR

C<WebSearch> is written by John Heidemann, <johnh@isi.edu>.


=head1 COPYRIGHT

Copyright (c) 1996-1997 University of Southern California.
All rights reserved.                                            
                                                               
Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation, advertising
materials, and other materials related to such distribution and use
acknowledge that the software was developed by the University of
Southern California, Information Sciences Institute.  The name of the
University may not be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.



=cut

use strict;

&usage if ($#ARGV == -1);
&usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');

BEGIN {
    # The next lines are a testing hacks.
!NO!SUBS!
   print OUT 'unshift (@INC, "/home/johnh/WORKING/LSAM/RENDEZVOUS/lib/"); # for john', "\n" if ($debug);
print OUT <<'!NO!SUBS!';
#  unshift (@INC, "/nfs/u1/wls/cvs/lsam/rendezvous/lib/"); # for wls
}

use WWW::Search;
use Getopt::Long;

my(%opts);
$Getopt::Long::getopt_compat = 1;   # avoid parsing +'s as options (doesn't work!)
&GetOptions(\%opts, qw(v a e=s m=s o=s@ r)); # i.e -v -e=<string> -o=<options>

&usage if ($#ARGV == -1); # we MUST have one left, the query

my($verbose) = $opts{'v'};
my($all) = $opts{'a'};
my($raw) = $opts{'r'};
my($maximum_to_retrieve) = $opts{'m'};

&main(join(" ", @ARGV));

exit 0;

sub print_result {
    my($result, $count) = @_;

    my($prefix) = "";
    $prefix = sprintf("[%3d] ", $count) if defined($verbose);

    if (defined($all)) {
        foreach ($result->urls()) {
            print "$prefix$_\n";
            $prefix = "      ";
        };
    } else {
	if (defined($raw)) {
	    print $result->raw(), "\n";
	} else {
	    print $prefix, $result->url, "\n";
	};
    };
}

sub print_error {
    my($error, $count) = @_;

    my($prefix) = "";
    $prefix = sprintf("[%3d] ", $count) if defined($verbose);

    print $prefix, $error, "\n";
}

sub main {
    my($query) = @_;
    my($count) = 0;
    my($search) = new WWW::Search($opts{e});
    my($query_options_ref);

    if (defined($opts{'o'})) {
        $query_options_ref = {};
        foreach (@{$opts{'o'}}) {
            my($key, $value) = m/^([^=]+)=(.*)$/;
            $query_options_ref->{$key} = WWW::Search::escape_query($value);
        };
    };

    if (defined($maximum_to_retrieve)) {
	$search->maximum_to_retrieve($maximum_to_retrieve);
    } else {
	$maximum_to_retrieve = 10000;
    };

    $search->native_query(WWW::Search::escape_query($query), $query_options_ref);

    my($way) = 0; # 0=piecemeal, 1=all at once
    my($result);
    if ($way) { # return all at once.
        foreach $result ($search->results()) {
            print_result($result, ++$count);
	    last if ($count > $maximum_to_retrieve);
        };
    } else { # return page by page
        while ($result = $search->next_result()) {
            print_result($result, ++$count);
	    last if ($count > $maximum_to_retrieve);
        };
    };
    # handle errors
    if ($count == 0) {
        my($response) = $search->response();
	my($nothing) = "Nothing found.";
        if ($response->is_success) {
            print_error($nothing, $count);
        } else {
            print_error("Error:  " . $response->as_string(), $count);
        };
    };

};


!NO!SUBS!
