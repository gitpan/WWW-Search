use Config;
use File::Basename qw(basename dirname);
chdir(dirname($0));
($file = basename($0)) =~ s/\.PL$//;
$file =~ s/\.pl$//
      if ($Config{'osname'} eq 'VMS' or
          $Config{'osname'} eq 'OS2');  # "case-forgiving"
$debug = (`hostname` =~ /^copper/);   # development hack
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
# $Id: WebSearch.PL,v 1.12 1999/10/08 14:25:24 mthurn Exp $
#
# Complete copyright notice follows below.
#


sub usage 
  {
  my $msg = shift;
  defined($msg) && ($msg ne '') && print STDERR "$0: $msg\n";
  print STDERR <<"END";
usage: WebSearch [--engine <name>] [--max <integer>] [--options <key=value>]... [--count] [--all] [--raw] [--verbose] [--VERSION] [--help] [--lwpdebug] [--debug] query

Make a query to a web search engine, printing to STDOUT the URLs which match (one per line).

See `perldoc WebSearch` for details.

END
  exit 1;
  } # usage


=head1 NAME

WebSearch - a web-searching application demonstrating WWW::Search


=head1 SYNOPSIS

B<WebSearch [-m MaxCount] [-e SearchEngine] [-o option] [-o option...] [-ardvV] query>


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

WebSearch uses Getopt::Long, so you can use double-minus with long
option names, or single-minus with one-letter abbreviations.

=over 8

=item --engine e_name, -e e_name

The string e_name is the name of (the module for) the desired search
engine.  Capitalization matters.  See `perldoc WWW::Search` to find
out what the default is (normally AltaVista)

See L<WWW::Search> for a complete list of supported engines.

=item --max max_count, -m max_count

Specify the maximum number of hits to retrieve.

=item --option o_string, -o o_string

Specify a search-engine option in the form 'key=value' (or just
'key').  Can be repeated for as many options are needed.  Keys can be
repeated.

=item --count, -c

As the first line of output, print the approximate hit count. 

=item --all, -a

For each hit result, print all the URLs that the search engine
indicated were equivalent to it.  (Some URLs may refer to the same
object.)  Can be combined with --verbose; can not be combined with
--raw.

=item --raw, -r

For each hit result, print the raw HTML.

=item --verbose, -v

Verbose mode.  Enumerate the returned URLs and show the description,
score, date, etc. for each.

=item --VERSION, -V

Print version information and exit immediately.

=item --debug <i>, -d <i>

Display back-end debugging information (with debug level <i>)

=item --lwpdebug, -l

Display low-level libwww-perl debugging information

=back


=head1 ENVIRONMENT VARIABLES

The environment variable F<http_proxy> (or F<HTTP_PROXY>)
specifies a proxy, if any.


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

&usage('no arguments given') if ($#ARGV == -1);
# &usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');

BEGIN {
    # The next lines are a testing hacks.
!NO!SUBS!
   print OUT 'unshift (@INC, "/home/johnh/WORKING/LSAM/RENDEZVOUS/lib/"); # for john', "\n" if ($debug);
print OUT <<'!NO!SUBS!';
#  unshift (@INC, "/nfs/u1/wls/cvs/lsam/rendezvous/lib/"); # for wls
}

use WWW::Search;
use Getopt::Long;

use vars qw( $VERSION );
$VERSION = '2.10';

use vars qw( $sEngine $all $verbose $raw $maximum_to_retrieve $print_version $debuglwp $debug );
use vars qw( @options $_host $_port $help $iShowCount );
# Set default values:
$iShowCount = 0;
$_host = '';
$_port = '';
undef $debug;
$debuglwp = 0;
# Get the command-line options:
&Getopt::Long::config(qw(no_ignore_case no_getopt_compat));
&usage('getopt failed') unless &GetOptions('all', \$all, 'raw', \$raw,
            'verbose', \$verbose,  'VERSION', \$print_version,
            'count', \$iShowCount,
            'max=i', \$maximum_to_retrieve,
            'engine=s', \$sEngine,
            'lwpdebug', \$debuglwp,
            'debug:i', \$debug,
            'options=s@', \@options,
            'host=s', \$_host,  'port=s', \$_port,
            'help', \$help,
           );
&usage('user requested help') if $help;
$debug = 1 if (defined($debug) and ($debug < 1));

&print_version if defined($print_version);
# there MUST be some argument(s) left, the query:
&usage('no query found on command line') if (scalar(@ARGV) <= 0); 

&main(join(" ", @ARGV));

exit 0;

sub print_version 
  {
  print "$0 version $VERSION\n  WWW::Search version $WWW::Search::VERSION\n";
  exit 0;
  } # print_version

my($verbose_code);

sub print_result {
    my($result, $count) = @_;

    my($prefix) = "";
    if ($verbose) {
	my(@attribs) = ();
        $prefix = "$count. ";
	if (!defined($verbose_code)) {
	    $verbose_code = "";
	    foreach (qw(title description score normalized_score size change_date index_date)) {
	        $verbose_code .= "push(\@attribs, \"$_: \" . \$result->$_())\n" .
		    "\tif (defined(\$result->$_()));\n";
            };
	};
	eval $verbose_code;
        $prefix .= "(" . join(",\n\t", @attribs) . ")\n\t"
	    if ($#attribs >= 0);
    };

    if (defined($all)) {
        foreach ($result->urls()) {
            print "$prefix$_\n";
            $prefix = "\t";
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
    my ($msg, $count) = @_;
    my $error = $verbose ? sprintf("[%3d] ", $count) : '';
    $error .= $msg;
    print STDERR $error, "\n" if $error ne '';
}

sub main {
    my($query) = @_;
    my($count) = 0;
    my($search) = new WWW::Search($sEngine);
    $search->{_host} = $_host if $_host ne '';
    $search->{_port} = $_port if $_port ne '';
    my %hsOptions = ();

    if (0 < $debuglwp) {
	require LWP::Debug;
	LWP::Debug::level('+');
    }

    $search->http_proxy($ENV{'HTTP_PROXY'}) if ($ENV{'HTTP_PROXY'});
    $search->http_proxy($ENV{'http_proxy'}) if ($ENV{'http_proxy'});
         
    if (0 < scalar(@options)) 
      {
      foreach my $sPair (@options) 
        {
        if ($sPair =~ m/^([^=]+)=(.*)$/)
          {
          my ($key, $value) = ($1, $2);
          # This is a bit of a hack.  A set of CGI options is not
          # strictly a hash, because multiple values for the same key
          # can be specified.  To get around this, we rely on the fact
          # that this hash of options is only used to construct a CGI
          # parameter list.  If we see multiple values for the same key,
          # we append the multiple values onto the value of the key in
          # CGI '?key=value' format.
          if (exists($hsOptions{$key}) && $hsOptions{$key} ne '')
            {
            # There was already an option of this key given; append
            # multiple values as CGI arguments:
            $hsOptions{$key} .= '&'.$key.'='.WWW::Search::escape_query($value);
            } # if exists
          else
            {
            # This is the only instance of this key; just insert the
            # hash value:
            $hsOptions{$key} = WWW::Search::escape_query($value);
            }
          } # if option is of the form key=value
        else
          {
          $hsOptions{$sPair} = '';
          }
        } # foreach $sPair
      } # if @options

    if (defined($maximum_to_retrieve)) {
	$search->maximum_to_retrieve($maximum_to_retrieve);
    } else {
	$maximum_to_retrieve = 10000;
    };

    $hsOptions{'search_debug'} = $debug if (defined($debug) and (0 < $debug));

    $search->native_query(WWW::Search::escape_query($query), \%hsOptions);

    my($way) = 0; # 0=piecemeal, 1=all at once
    my($result);
    if (($iShowCount) and defined($search->approximate_result_count))
      {
      print "There are approximately " if $verbose;
      print $search->approximate_result_count;
      print " results." if $verbose;
      print "\n";
      }
    if ($way) { # return all at once.
        foreach $result ($search->results()) 
          {
          print_result($result, ++$count);
	  last if ($count > $maximum_to_retrieve);
          };
    } else { # return page by page
        while ($result = $search->next_result()) 
          {
          print_result($result, ++$count);
	  last if ($count > $maximum_to_retrieve);
          } # while
      } # else page by page
    # handle errors
    if ($count == 0) {
        my($response) = $search->response();
	my $nothing = $verbose ? "Nothing found." : '';
        if ($response->is_success) {
            print_error($nothing, $count);
        } else {
            print_error("Error:  " . $response->as_string(), $count);
        };
    };

};


!NO!SUBS!
