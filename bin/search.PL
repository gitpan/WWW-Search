use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
      if ($Config{'osname'} eq 'VMS' or
          $Config{'osname'} eq 'OS2');  # "case-forgiving"
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
# search.pl
# Copyright (C) 1996 by USC/ISI
# $Id: search.PL,v 1.15 1996/11/11 18:35:28 johnh Exp $
#
# Complete copyright notice follows below.
#


sub usage {
    print STDERR <<END;
usage: $0 [-e SearchEngine] [-o option] [-o option...] [-v] query

Make a query to Alta Vista, showing the primary URLs which match.
END
    exit 1;
}


=head1 NAME

search - a web-searching application demonstrating WWW::Search


=head1 SYNOPSIS

B<search [-e SearchEngine] [-o option] [-o option...] [-va] query>


=head1 DESCRIPTION

This program is provides a command-line interface to web search engines,
listing all URLs found for a given query.  This program also provides
a simple demonstration of the WWW::Search Perl library for web searches.

Currently the program does searches on AltaVista 
F<http://www.altavista.digital.com>.
We plan to expand WWW::Search to support other search engines 
in late 1996.

We plan to provide more sophisticated services using WWW::Search.
One service is an periodic service where we automatically search
the web for relevant documents.  A prototype of this system 
(not yet using WWW::Search) is available at
F<http://www.isi.edu/lsam/tools/index.html>
with sample output at
F<http://www.isi.edu/div7/ib/jog/index.html>.


=head1 OPTIONS

=over 8

=item C<-e>

Specify the search engine.
Capitalization matters.
Currently AltaVista, Lycos, and HotBot are possible engines.
See L<WWW::Search> for a possibly more complete list of supported engines.

=item C<-o>

Specify a search-engine option.

=item C<-v>

Verbose mode.  Enumerate the returned URLs.

=item C<-a>

Return all URLs.  Some different URLs may refer to the same object.

=back


=head1 SEE ALSO

For the library, see L<WWW::Search>.

For a more sophisticated, see L<AutoSearch>.


=head1 AUTHOR

C<WWW::Search> is written by John Heidemann, <johnh@isi.edu>,
with some additions by Wm. L. Scheding, <wls@isi.edu>.


=head1 COPYRIGHT

Copyright (c) 1996 University of Southern California.
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
#  unshift (@INC, "./lib/"); # for john
#  unshift (@INC, "/nfs/u1/wls/cvs/lsam/rendezvous/lib/"); # for wls
}

use WWW::Search;
use Getopt::Long;

my(%opts);
&GetOptions(\%opts, qw(v a e=s o=s@)); # i.e -v -e=<string> -o=<options>

&usage if ($#ARGV == -1); # we MUST have one left, the query

my($verbose) = $opts{'v'};
my($all) = $opts{'a'};

&main(join(" ", @ARGV));

exit 0;

sub print_result {
  my($result, $count) = @_;

  my($prefix) = "";
  $prefix = "[$count] " if defined($verbose);

  if ($all) {
    foreach ($result->urls()) {
      print "$prefix$_\n";
      $prefix = "      ";
    };
  } else {
    print $prefix, $result->url, "\n";
  };
}

sub main {
  my($query) = @_;
  my($count) = "001" if defined($verbose);
  my($search) = new WWW::Search($opts{e});
  my($query_options_ref);

  if (defined($opts{'o'})) {
    $query_options_ref = {};
    foreach (@{$opts{'o'}}) {
      my($key, $value) = m/^([^=]+)=(.*)$/;
      $query_options_ref->{$key} = WWW::Search::escape_query($value);
    };
  };

  $search->native_query(WWW::Search::escape_query($query), $query_options_ref);

  my($way) = 0; # 0=piecemeal, 1=all at once
  my($result);
  if ($way) { # return all at once.
    foreach $result ($search->results()) {
      print_result($result, $count++);
    };
  } else { # return page by page
    while ($result = $search->next_result()) {
      print_result($result, $count++);
    };
  };
};



!NO!SUBS!
