exit 0;
# The above line will be stripped off during `make`
#
# AutoSearch-code.pl
# Copyright (c) 1996-1997 University of Southern California.
# All rights reserved.
# $Id: AutoSearch-code.pl,v 1.2 2001/04/11 14:42:21 mthurn Exp mthurn $
#
# Complete copyright notice follows below.

=head1 NAME

AutoSearch -- a web-searching application

=head1 SYNOPSIS

B<AutoSearch -n "My Query On Engine" -s "unescaped query" [--engine SearchEngine] [--option QueryOptions]... [--filter FilterRegExp] [--verbose] [--stats] qid>

B<AutoSearch qid>

=head1 DESCRIPTION

B<AutoSearch> performs a web-based search and puts the results
set in F<qid/index.html>.
Subsequent searches (i.e., the second form above)
B<AutoSearch> determine what changes (if any) occured to the 
results sent since the last run.
These incremental changes are recorded in F<qid/YYYYMMDD.html>.
B<AutoSearch> is amenable to be run as a B<cron> job because all
the input parameters are saved in the web pages.  B<AutoSearch> 
can act as a automated query agent for a particular search.  The output
files are designed to be a set of web pages to easily display the
results set with a web browser.

Example:

    AutoSearch -n 'LSAM Replication'
	-s '"lsam replication"'
	-e AltaVista
	replication_query

This query (which should be all on one line)
creates a directory replication_query
and fills it with the facinating output of the AltaVista query
on C<"lsam replication">,
with pages titled ``LSAM Replication''.
(Note the quoting:  the single quotes in
C<'"lsam replication"'> are for the shell,
the double quotes are for AltaVista
to search for the phrase rather than the separate words.)

A more complicated example:

    AutoSearch -n 'External Links to LSAM'
	-s '(link:www.isi.edu/lsam or link:www.isi.edu/~lsam) -url:isi.edu'
	-e AltaVista::AdvancedWeb
	-o coolness=hot

This query does an advanced AltaVista search
and specifies the (hypothetical) ``coolness'' option
to the search engine.

=head1 OPTIONS

=over 8

=item qid

The I<query identifer> specifies the directory in which all the
files that relate to this query and search results will live.

=item C<-stats>

Show search statistics: the query string,
number of hits, number of filtered hits,
filter string, number of suspended (deleted) hits,
previous set size, current set size.

=item C<-v>

Verbose: output additional messages and warnings.

=item C<-n>

Specify the query name.  The query name is used to construct the web
page.  The query name is used as a heading for the web pages and
should be a 'nice' looking version of the query string.

=item C<-s>

Specify the query string.  The query string is the character string
which will be submitted to the search engine.  You may include special
characters to group or to qualify the search.

=item C<-e> C<--engine>

Specify the search engine.  The query string will be submitted 
to the user specified search engine.  The default is B<AltaVista>.
Other search engines supported are B<Lycos>, B<HotBot>, and B<Yahoo>.

In many cases there are specialized versions of search engines.
For example, B<AltaVista::AdvancedWeb> and B<AltaVista::News>
allow more powerful and Usenet searches.
See L<AltaVista> or the man page for your search engine
for details about specialized variations.

=item C<-o> C<--options>

Specify the query options.  The query options will be submitted 
to the user search engine with the query string.  This feature
permits modification of the query string for a specific search
engine or option.  More than one query option may be specified.

Example:
C<-o what=news>
causes AltaVista to search Usenet.
Although this works, the preferred mechanism
in this case would be C<-e AltaVista::News> or C<-e AltaVista::AdvancedNews>.
Options are intended for internal or expert use.


=item C<-f> C<--filter>

Specify the URL filter regular expression.
This option specifies a regular expression which will
be compared against the URLs of any results;
if they match the case-insensitive regular expression, they will be removed
from the hit set.
If the web pages created by AutoSearch are
publically available (and indexed),
they should be filtered out with this option.

Example: 
C<-f '.*\.isi\.edu'> avoids all of ISI's web pages.

=back


=head1 DESCRIPTION

B<AutoSearch> submits a query to a search engine, produces HTML
pages that reflect the set of 'hits' (filtered search results)
returned by the search engine, and tracks these results over time. 
The URL and title are displayed in the F<qid/index.html>, the URL, 
the title, and description are displayed in the 'weekly' files.

To organize these results, each search result is placed in a query
information directory (qid).  The directory becomes the search
results 'handle', an easy way to track a set of results.
Thus a qid of C</usr/local/htdocs/lsam/autosearch/load_balancing>
might locate the results on your web server at
C<http://www.isi.edu/lsam/autosearch/load_balancing>.

Inside the qid directory you will find files relating to this query.
The primary file is F<index.html>, which reflects the latest
search results.  Every not-filtered hit for every search is stored
in F<index.html>.
When a hit is no longer found by the search engine
it a removed from F<index.html>.
As new results for a search are returned from the search engine they are placed
in F<index.html>.

At the bottom of F<index.html>, there is a heading "Weekly Search Results",
which is updated each time the search is submitted
(see L<AUTOMATED SEARCHING>).
The list of search runs is stored in reverse chronological order.
Runs which provide no new information are identified with

	No Unique Results found for search on <date>

Runs which contain changes are identified by

	Web search results for search on <date>

which will be linked a page detailing the changes from that run.

Detailed search results are noted in weekly files.  These files are
named F<YYYYMMDD.html> and are stored in the qid directory.  The
weekly files include THE URL, title, and a the description (if
available).  The title is a link to the original web page.


=head1 AUTOMATED SEARCHING

Cron(1) may be used to establish periodic searches and the web pages
will be maintained by B<AutoSearch>.  To establish the first search,
use the first example under SYNOPSIS.  You must specify the qid, query
name and query string.  If any of the items are missing, you will be
interactively prompted for the missing item(s).

Once the first search is complete you can re-run the search with the
second form under SYNOPSIS.
A cron entry like:

    0 3 * * 1 /nfs/u1/wls/AutoSearch.pl /www/div7/lsam/autosearch/caching

might be used to run the search each Monday at 3:00 AM.  The
query name and query string may be repeated; but they will not be
used.  This means that with a cron line like:

    0 3 * * 1 /nfs/u1/wls/AutoSearch.pl /www/div7/lsam/autosearch/caching -n caching -s caching

a whole new search series can be originated by

    rm -r /www/div7/lsam/autosearch/caching

However, the only reason to start a new search series would be to 
throw away the old weekly files.

We don't recommend running searches more than once per day,
but if so the per-run files will be updated in-place.
Any changes are added to the page with a comment that
"Recently Added:"; and deletions are indicated with "Recently Suspended:."


=head1 CHANGING THE LOOK OF THE PAGES

The basic format of these two pages is simple and customizable.  One
requirement is that the basic structure remain unchanged.  HTML
comments are used to identify sections of the document.  Almost
everything can be changed except for the strings which identify the
section starts and ends.

Noteworthy tags and their meaning:

=over 16

=item <!--Top-->.*<!--/Top-->

The text contained within this tag is placed at the top of the output
page.  If the text contains I<AutoSearch WEB Searching>, then the
query name will replace it.  If the text does not contain this
magic string and it is the first ever search, the user will be asked for
a query name.

=item <!--Query{.*}/Query-->

The text contained between the braces is the query string.  This is how
B<AutoSearch> maintains the query string.  You may edit this
string to change the query string; but only in F<qid/index.html>.
The text I<ask user> is special and will force B<AutoSearch>
to request the search string from the user.

=item <!--SearchEngine{.*}/SearchEngine-->

The text contained between the braces is the search engine.  The
default engine is AltaVista.
Other engines supported are HotBot
and Lycos.  You may edit this
string to change the query string; but only in F<qid/index.html>.
The text I<ask user> is special and will force B<AutoSearch> to
to request the search string from the user.

=item <!--QueryOptions{.*}/QueryOptions-->

The text contained between the braces specifies a query options.
Multiple occurrencs of this command are allowed to specify multiple
options.

=item <!--URLFilter{.*}/URLFilter-->

The text contained between the braces is the URL filter.  This is how
B<AutoSearch> maintains the filter.  Again you may edit this
string to change the query string; but only in F<qid/index.html>.
The text I<ask user> is special and will force B<AutoSearch> to
ask the user (STDIN) for the query string.  When setting up the first
search, you must edit F<first_index.html>, not F<qid/index.html>.
The URL filter is a standard perl5 regular expression.  URLs which
do not match will be kept.

=item <!--Bottom-->.*<!--/Bottom-->

The text contained within this tag is placed at the bottom of the output
page.  This is a good place 
to put navigation, page owner information, etc.

=back

The remainder of the tags fall into a triplet of I<~Heading>,
I<~Template>, and I<~>, where ~ is Summary, Weekly, Appended,
and Suspended. The sub-sections appear in the order given. 
To produce a section B<AutoSearch> outputs the heading, the template,
the section, n copies of the formatted data, and an /section.
The tags and their function are:

=over 16

=item ~Heading

The heading tag identifies the heading for a section of the output
file.  The SummaryHeading is for the summary portion, etc.  The
section may be empty (e.g., Suspended) and thus no heading is output. 

=item ~Template

The template tag identifies how each item is to be formatted.  Simple
text replacement is used to change the template into the actual
output text.  The text to be replaced is noted in ALLCAPS.

=item ~

This tag is used to locate the section (Summary, Weekly, etc.).  This
section represents the actual n-items of data.

=back

You can edit these values in the F<qid/index.html> page of an existing
search.  The file F<first_index.html> (in the directory above F<qid>)
will be used as a default template for new queries.

Examples of these files can be seen in the pages under
C<http://www.isi.edu/lsam/autosearch/>,
or in the output generated by a new AutoSearch.


=head1 FILES

=over 20

=item F<first_index.html>

optional file to determine the default format of the F<index.html> file
of a new query.

=item F<first_date.html>

optional file to determine the default format of the F<YYYYMMDD.html> file
for a new query.

=item F<qid/index.html>

latest search results and reverse chronological list of periodic searches.

=item F<qid/date.html>

file used as a template for the F<YYYYMMDD.html> files.

=item F<qid/YYYYMMDD.html>

summary of changes for a particular date (AKA 'Weekly' file).

=back

Optional files F<first_index.html> and F<first_date.html> are used for the
initial search as a template for F<qid/index.html> and F<date.html>,
respectively.  If either of these files does not exist; a default-default 
template is stored within the F<AutoSearch> source.  The intention
of these two files is to permit a user to establish a framework for
a group of search sets which have a common format.  By  leaving the 
default query name and query string alone, they will be overridden by
command line inputs.


=head1 SEE ALSO

For the library, see L<WWW::Search>,
for the perl regular expressions, see L<perlre>.


=head1 AUTHORS

Wm. L. Scheding

B<AutoSearch> is  a re-implementation of an earlier version written by Kedar Jog.


=head1 COPYRIGHT

Copyright (C) 1996-1997 University of Southern California.
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


=head1 DESIRED FEATURES

These are good ideas that people have suggested.

=over 4

=item URL validation.

Validate the status of each URL (with HTTP HEAD requests)
and indicate this status in the output.

=item Multi-search.

It should be possible to merge the results of searches from two
search-engines.
If this merger were done as a new search engine,
this operation would be transparent to AutoSearch.

=back


=head1 BUGS

None known at this time; please inform the maintainer
MartinThurn@iname.com if any crop up.

=cut

use strict;

&usage if ($#ARGV == -1);
&usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');

BEGIN
  {
  # next line is a release hack
  # push (@INC, "..");
  # unshift (@INC, "/nfs/u1/wls/cvs/lsam/rendezvous/lib");
  }

use Getopt::Long;
use POSIX qw(strftime);
use WWW::Search;

use vars qw( $VERSION );
$VERSION = '2.03';

sub print_version
  {
  print "$0 version $VERSION;  WWW::Search version $WWW::Search::VERSION\n";
  } # print_version

#=head1 NAME
#
#usage -  on command line errors list usage.
#
#
#=head1 DESCRIPTION
#
#
#=cut

sub usage {
  print STDERR <<END;
usage: $0 [--stats] [--verbose] -n "Query Name" -s "query string" --engine engine [--mail you\@where.com] [--options "query options"]... [--filter "filter"] [--host host] [--port port] query_id
Update or create a web search-engine query.
Unambiguous argument names can be abbreviated to one letter (e.g. -e engine -f "filter")
END
  exit 1;
}

my(%opts,@query_list,$query_name,$query_string,$search_engine,$query_options,$url_filter);
# Default options:
$opts{'m'} = '';
$opts{'v'} = 0;
$opts{'stats'} = 0;
&GetOptions(\%opts, qw(n|qn|queryname=s s|qs|querystring=s e|engine=s m|mail=s h|host=s p|port=s o|options=s@ f|uf|urlfilter=s stats v|verbose V|VERSION));
&print_version if $opts{'V'};

&usage if ($#ARGV == -1); # we MUST have one left, the qid

my $s_dbg = $opts{'stats'};
my $v_dbg = $opts{'v'};
if ($v_dbg)
  {
  print "v     option: defined\n";
  print "stats option: ", ! $opts{'stats'} ? 'not ' : '', "defined\n";
  } # if
if ($opts{'m'} ne '')
  {
  print STDERR "will send email summary to: ", $opts{'m'}, "\n" if $v_dbg;
  eval 'use MIME::Lite';
  if ($@ ne '')
    {
    print STDERR " --- can not load MIME::Lite module: ==$@==\n";
    } # if
  } # if

# if we want a list of args:
#@query_list = split(/[,\s]+/, $opts{'n'},2) if defined($opts{'n'});

$query_name =    $opts{'n'} if defined($opts{'n'});
$query_string =  $opts{'s'} if defined($opts{'s'});
$search_engine = $opts{'e'} if defined($opts{'e'});
if (defined($opts{'o'})) 
  {
  $query_options = {};
  foreach my $sPair (@{$opts{'o'}}) 
    {
    my ($key, $value) = $sPair =~ m/^([^=]+)=(.*)$/;
    &add_to_hash($key, &WWW::Search::escape_query($value), $query_options);
    }
  }
$url_filter =    $opts{'f'} if defined($opts{'f'});
my($local_filter) = 0; # shall we exclude our own old pages? (1=y,0=n)

#print "n = \"$opts{'n'}\"\n" if defined($opts{'n'});
#print "s = \"$opts{'s'}\"\n" if defined($opts{'s'});
#print "e = \"$opts{'e'}\"\n" if defined($opts{'e'});
#print "o = \"$opts{'o'}\"\n" if defined($opts{'o'});
#print "f = \"$opts{'f'}\"\n" if defined($opts{'f'});

##print "query_list   = \"$query_list[0]\" \"$query_list[1]\"\n";
#print "query_name    = \"$query_name\"\n"    if defined($opts{'n'});
#print "query_string  = \"$query_string\"\n"  if defined($opts{'s'});
#print "search_engine = \"$search_engine\"\n" if defined($opts{'e'});
#print "url_filter    = \"$url_filter\"\n"    if defined($opts{'f'});

&main(join(" ", @ARGV));

exit 0;

########
# subs #
########
#
# all the subroutine documentation has been disabled  -- oh for a ifdef
# someday -- put all the subs in another file & tech documentation
# from there, man page from main file.  wls :) 10/18/96 :(
#
#=head1 SUBROUTINES
#
#=cut
#
# Files expected first_date.html and first_index.html in the
# 'home' directory.  These are used to build the initial
# search files.
#
# To start a new search: specify a query name (-qn) and
# query string (-qs) (and more). If either are not provided, AS will
# ask the user (STDIN) for the name and/or the string as necessary.
# The string "AutoSearch WEB Searching" is replaced by the query name
# and the string "ask user" is replaced by the query string.
#
# AS 1.x accepts the basic query sub-directory identifier
# and looks to see if qid/date.html exists.  If this file
# file does not exist, AS looks for a file first_date.html
# If the default file in the parent directory is missing, AS
# creates a default-default file named qid/date.html.
# In any case the directory 'qid' is created.
# A second file first_index.html is used to create the initial
# qid/index.html file in a like fashon.
#
# (LATER: ADD SEARCH ENGINE(S))
# There are three important items which must be defined for any
# search that AS will process.  First the query-subdirectory
# identifier (qid).  This is the handle to this query.
# Once a query session is established; only the qid need be
# specified on the command line.
# Second is the 'pretty name' that you will assign to this
# Query.  This is used at the top of the screens to help
# the user identify what the searche topic is.  Third
# is the actual search string.  This is passed directly to
# search processor, and the search engine.
#
# File date.html is used to define the format of the pages which are
# created each time (weekly) AutoSearch.pl is run.  Major sections of
# the file are identified with html comments.  The search string is
# embedded in this file too.  One method of creating a new search is
# to create the new directory manually and create a file named
# date.html in the sub-directory.  However; this requires you to
# understand the tags and build a file which is compatible with AS.
#
# A second method is to manually copy first_date.html to qid/date.html
# and edit it.  This is the John method to introduce a new search.  It
# is cumbersome and not-automated-ish.
#
# A third approach involves using command line arguments to specify
# the query name and string.  This is the wls method.  One variation
# on the wls method is the "ask user" method.  In this approach, AS
# will ask the user for the required items.  In both of these methods
# the necessary files will be created.
#
# Once the initial search has been made and the files created, then
# the simple command "AutoSearch qid" will update the search files and
# pages.
#
#=head1 NAME
#
#main -  start of actual work.
#
#
#=head1 DESCRIPTION
#
#Submit a search and build output files.
#
#=cut

# submit a search and optionally build output file(s).
#
sub main {
  my($query_dir) = @_;
  my($dbg_search) = 0;
  my($v_dbg) = $v_dbg; # shall we be verbose??
  my $sEmail = '';
  my($url_filter_count) = 0;
# get the date.
  my($now) = &time_now;
  my($today) = &time_today;
  print "Now = ", $now if $v_dbg;
  print ", Today = ", $today, "\n" if $v_dbg;
# build query directory string.
  my($qid) = $query_dir;
  die ("qid is a required field.") unless ($qid);
  $qid .= '/' unless substr($qid,-1,1) eq '/'; # we MUST have a /
  print "query directory: $qid, " if $v_dbg;
# do we have the necessary infrastructure?
# we require two files. 1) the Summary of searches and 2) weekly updates
# look for index.html, or default first_index.html or make one.
# index.html contains the previous isearch results. (aka old summary)
  &check_index_file($qid); #make qid/index.html

# read index.html and break into fields.
  my($SummaryTop,$SummaryQuery,
     $SummarySearchEngine,$SummaryURLFilter,
     $SummaryHeading,$SummaryTemplate,$Summary,
     $WeeklyHeading,$WeeklyTemplate,$Weekly,
     $SummaryBottom,@SummaryQueryOptions)
   = &get_summary_parts($qid);
# split the old summary into a list. (later sort it)
  my($url,$description,$title);
  my(@old_summary_url,@old_summary_title);
  my(@old_summary) = split(/\n/,$Summary);
  my($line);
  my($i,$n,$j,$m);
# break each hyperlink into its url and title.
  $n = $#old_summary + 1;
  for ($i=0; $i < $n; $i++) {
    # $old_summary -> $url & $title
    $line = $old_summary[$i];
    if ($line =~ m#<a href="(.*)">(.*)</a><br>#i) {
      $url = $1;
      $title = $2;
      push (@old_summary_url,$url);
      push (@old_summary_title,$title);
    }
  }

# for each item in weekly list:
#   if it is in old summary list remove it, else leave it.
#  hint: note alphabetical order to reduce searching.
# append weekly list to summary list. sort it.
# use summary list to build a new summary.
# output first half of the NEW index.html page. (summary)
# append either "no new results" (if zero unique left in weekly list)
# or the date to weekly results list.
# output second half of NEW index.html page. (weekly results)
#
# if non-zero use weekly list to build weekly file.

# these are the input params to autosearch:
# 1) qid, 2) query name, 3) query string, 4) search engine,
# 5) query options, and 6) url filter RE.
# Dispose of input params as follows:
# insert the Query Name into 'Top' for  index.html & date.html,
# insert the Query String, Search Engine, and URL Filter into
# the 'HTML fields' from index.html
# Precedence of input: Query Name (pretty name) and Query String (search engine)
# Search Engine (AltaVista), Search Options (## need example ##),
# URL Filter (to suppress display and tracking of particular URLs)
# 1) from existing file or default files (files already in place), or
# 2) from user.
#    (either a) command line or b) "ask user" (or error if we don't dare))
  my($QueryName,$QueryString,$SearchEngine,$URLFilter);
# did we get a Query Name/String/Engine/Options/Filter from existing files?
  if ($SummaryTop =~ m/AutoSearch WEB Searching/i) { # no
    if (defined($query_name)) { # from command line
      $QueryName = $query_name;
    } else { # no, ask 'em
      $QueryName = &read_query("Please enter a Query Name:");
    }
    $SummaryTop =~ s/AutoSearch WEB Searching/$QueryName/i;
    print "Query Name is \"$QueryName\"\n" if $v_dbg;
  }

  if ($SummaryQuery =~ m/ask user/i)
    { # no
    if (defined($query_string)) { # from command line
      $QueryString = $query_string;
      } else { # no, ask 'em
        $QueryString = &read_query("Please enter a Query String:");
        }
    $SummaryQuery =~ s/ask user/$QueryString/i;
    print "Query String is \"$QueryString\"\n" if $v_dbg;
    }
  my $sTitle = "<Title> Search results for $SummaryQuery as of $now </Title>\n";
  
# this is not a required field.
# this MUST BE ask user to get AutoSearch to ask.
  if ($SummarySearchEngine =~ m/ask user/i) { # no, shall we ask the user
    if (defined($search_engine)) { # from command line ?
      $SearchEngine = $search_engine;
    } else { # no, ask 'em
      $SearchEngine = &read_query("Please enter a Search Engine:");
    }
    $SummarySearchEngine =~ s/ask user/$SearchEngine/i;
  } else { # don't ask; try command line
    if (defined($search_engine)) { # from command line ?
      $SearchEngine = $search_engine; # yes
    } else { # if no comamnd line, no Search Engine!!
      $SearchEngine = $SummarySearchEngine; # use whatever was in the first_index.html file
    }
    $SummarySearchEngine = $SearchEngine;
  }
  print "Search Engine is \"$SearchEngine\"\n" if $v_dbg;

# this is not a required field.
# this MUST BE ask user to get AutoSeatch to ask.
# 
#  print $SummaryQueryOptions[0], " v. ask user\n";
  if ($SummaryQueryOptions[0] =~ m/ask user/i) { # either ask or use command line
#    print $SummaryQueryOptions[0], " is ask user\n";
    if (defined($opts{'o'})) { # from command line ?
#      print "defined.\n";
      # use $query_options
    } else { # no, ask 'em
#      print "not defined.\n";
      @SummaryQueryOptions = &read_query_list("Please enter Query Options:");
      $query_options = {};
      foreach (@SummaryQueryOptions) {
        next if m/^$/;
        my($key, $value) = m/^([^=]+)=(.*)$/;
#        print "option:$_ is $key=$value\n";
        &add_to_hash($key, &WWW::Search::escape_query($value), $query_options);
      }
    }
  } else { # or use what came from index.html file
    $query_options = {};
    foreach (@SummaryQueryOptions) {
      next if m/^$/;
      my($key, $value) = m/^([^=]+)=(.*)$/;
      # print "option:$_ is $key=$value\n";
      &add_to_hash($key, &WWW::Search::escape_query($value), $query_options);
    }
  }

# this is not a required field.
# this MUST BE ask user to get AutoSearch to ask.
  if ($SummaryURLFilter =~ m/ask user/i) { # no, shall we ask the user
    if (defined($url_filter)) { # from command line ?
      $URLFilter = $url_filter;
    } else { # no, ask 'em
      $URLFilter = &read_query("Please enter a URL Filter:");
    }
    $SummaryURLFilter =~ s/ask user/$URLFilter/i;
  } else { # don't ask; try command line
    if (defined($url_filter)) { # from command line ?
      $URLFilter = $url_filter; # yes
    } else { # if no comamnd line, no filter!!
      $URLFilter = $SummaryURLFilter; # use whatever was in the first_index.html file
    }
    $SummaryURLFilter = $URLFilter;
  }
  print "URL Filter is \"$URLFilter\"\n" if $v_dbg;
#
# now locate the weekly format file.
# 1) qid/date.html, or 2) first_date.html, or 3) create one.
  &check_date_file($qid,$QueryName,$QueryString); #make qid/date.html

# read date.html and break into fields.
# make the search results into a list of urls, title, & descr).
# (later sort it)
# note: Top & Bottom CAN BE different from index.html.
  my($WeeklyTop,
     $AppendedHeading,$AppendedTemplate,$Appended,
     $SuspendedHeading,$SuspendedTemplate,$Suspended,
     $WeeklyBottom)
   = &get_weekly_parts($qid);
# insert queryname into html Top from date.html
# usually this is not seti up, because when we created the file we didn't
# have the data.  Do we have the Query Name?
  if ($WeeklyTop =~ m/AutoSearch WEB Searching/i) { # no
    $WeeklyTop =~ s/AutoSearch WEB Searching/$QueryName/i # use the summary.
  } # else, yes.

  my($hits) = 0; # actual no. of hits.
  my($saved) = 0; # actual no. saved.
  # duh! This must be outside the if () {} else {}; because of scope!
  my($search);
  # search AltaVista, or whatever the user has specified.
  if($SummarySearchEngine) {
    $search = new WWW::Search($SummarySearchEngine);
  } else {
    $search = new WWW::Search(undef()); # must be undef to get default.
  }
  $search->{_host} = $opts{'h'} if defined($opts{'h'});
  $search->{_port} = $opts{'p'} if defined($opts{'p'});
  $search->http_proxy($ENV{'HTTP_PROXY'}) if ($ENV{'HTTP_PROXY'});
  $search->http_proxy($ENV{'http_proxy'}) if ($ENV{'http_proxy'});
  # submit search w/options.
  $search->native_query(WWW::Search::escape_query($SummaryQuery), $query_options);
  # examine search results
  my($result,@results);
  my($next_result);
  my(@new_weekly_url,@new_weekly_title,@new_weekly_description);
  my(@weekly_url,@weekly_title);

# care to see the old summary list?
#  print "old summary:\n";
#  foreach $line (@old_summary_url) {
#    print "$line\n";
#  }

  # how many hits?
  # convert latest search results to a list of urls (descriptions & titles)
  # filtered by $SummaryURLFilter called new_weekly_*
  NEXT_URL:
  while ($next_result = $search->next_result()) { # page-by-page
    $url = $next_result->url;
    $hits++; # how many were returned?
    if ($local_filter) { # exclude old pages from prev. version?
      # let's not display references to our own pages.
      next if $url =~ m,www\.isi\.edu/div7/ib/(.+)/(\d+)\.html$,o;
      # let's not display references to our old pages.
      next if $url =~ m,www\.isi\.edu/div7/ib/jog,o;
    }
    # let the user filter out URLs.
    if ( ($SummaryURLFilter) && ($url =~ m,$SummaryURLFilter,oi) ) {
#      print "filter out $url \n with filter: $SummaryURLFilter\n";
      $url_filter_count++;
      next;
    }
    $saved++; # how many were saved?
    push(@weekly_url,$url); # the complete set of hits
    $title = $next_result->title;
    push(@weekly_title,$title);
    # was it in the old summary? if so, don't save it.
    # if not, it is a new search results for this week.
    foreach $line (@old_summary_url) {
      # see if this url is in the summary
      # skip if we've seen this b4
      next NEXT_URL if $url eq $line;
    }
    print "url:$url ** new result **\n" if $dbg_search;
    $description = $next_result->description;
    print "description: ", $description, "\n" if $dbg_search;
    print "title: ", $title, "\n" if $dbg_search;
    push(@new_weekly_url,$url); # the newest set of hits (added)
    push(@new_weekly_description,$description);
    push(@new_weekly_title,$title);
  }
  # report errors
  if ($hits == 0) {
    my($response) = $search->response();
    if ($response->is_success) {
      print "Warning:  Empty results set.\n" if defined($v_dbg);
    } else {
      print "Error: " . http_error_as_nice_string($response) . "\n";
    }
  }

  # only save the ones that don't show up in the current query list.
  # those we shall call suspended_*
  my(@suspended_url,@suspended_title);
  # we must use for loop to get the urls to match their descr & title.
  $n = $#old_summary_url + 1;
  $m = $#weekly_url + 1;
  OLD_URL:
  for ($i=0; $i < $n; $i++) {
    $url = $old_summary_url[$i];
    for ($j=0; $j < $m; $j++) {
      $line = $weekly_url[$j];
      # if we match the weekly (active search) hits, skip it.
      next OLD_URL if $url eq $line;
    }
    printf "suspend:\n [%02d]%s\n",$i,$url if $dbg_search;
    # not found? save it, it's been suspended
    push(@suspended_url,$url);
    $title = $old_summary_title[$i];
    push(@suspended_title,$title);
  }
  # stats?? (to see 'em use -stats)
  print "Query is : \"$SummaryQuery\" on \"$SummarySearchEngine\"" if defined($s_dbg);
  print " with \"@SummaryQueryOptions\"" if (defined($s_dbg) && $#SummaryQueryOptions);
  print "\n" if defined($s_dbg);
  print "old summary count: ",$#old_summary_url + 1,"\n" if defined($s_dbg);
  print "raw hits         : ",$hits,"\n" if defined($s_dbg);
  print "urls filtered    : ",$url_filter_count,", filter \"",$URLFilter,"\"\n" if defined($s_dbg);
  print "not filtered     : ",$saved,"\n" if defined($s_dbg);
  print "results set count: ",$#new_weekly_url + 1,"\n" if defined($s_dbg);
  print "suspended count  : ",$#suspended_url + 1,"\n" if defined($s_dbg);
  print "final count      : ",$#weekly_url + 1,"\n" if defined($s_dbg);
  my($changes) = (($#new_weekly_url != -1) || ($#suspended_url != -1));
#  printf "changes is %d\n",$changes if defined($v_dbg);

# For every search, AutoSearch (aka AS) will make a 'weekly' file.
# Usually AutoSearch is run as a 'cron' job; but can be run manually.
# AS will attempt to handle multiple (non-concurrent) runs per day.
  my($file) = (&time_file_of_the_day_numeric).'.html';
  my($section);

# to test this 'diff' code 1) rm -r qid/* 2) run AS -stats qid -qn -qs
# 3) edit qid/index.html remove some, add some (new urls)
# 4) run AS -stats qid; look at <today>.html
# you will see 'deleted' (from above) as 'recently added' &
# 'added' (from above) as 'recently suspended'
# reason: the changes were forced in 'old summary',
# usually (normal, non-testing cases) the changes will appear in new_weekly_*
# now if this is a run that adds information (re) write the file.
#
# do we have a reason to care? New Results, Appensions, Suspensions???
  if ($changes) {
#    print "test file: $qid$file\n";
    if (-e $qid.$file) { # file already there modify it.
#      print "modify existing weekly file.\n" if defined($v_dbg);
      # copy in previous file from today
      open (PARTS,'<'.$qid.$file) || die "Can't open weekly input file.\nReason: $!\n";
      my($part) = <PARTS>;
      close (PARTS);
#      print "Part:\"$part\"\n";
      # break into parts to insert modifications
      my($part1,$part2) = split (/<!--\/Appended-->/,$part,2);
      my($part3,$part4) = split (/<!--\/Suspended-->/,$part2,2);
      # write back out w/ changes.
      open (HTML,'>'.$qid.$file) || die "Can't open weekly output file.\nReason: $!\n";
      print HTML $part1;
      $n = $#new_weekly_url + 1;
      if ($n) {
        print HTML "<!--more...-->\n";
        print HTML "<h4>Recently Added:</h4><p>\n";
      }
      # format each unique result.
      for ($i=0; $i < $n; $i++) {
        $url = $new_weekly_url[$i];
        $title = $new_weekly_title[$i];
        $description = $new_weekly_description[$i];
        print HTML &make_link($AppendedTemplate,$url,$title,$description),"\n";
      }
      print HTML "<!--/Appended-->"; # replace due to split
      print HTML $part3;
      $n = $#suspended_url + 1;
      if ($n) {
        print HTML "<!--less...-->\n";
        print HTML "<h4>Recently Suspended:</h4><p>\n";
      }
      # format each suspended result.
      for ($i=0; $i < $n; $i++) {
        $url = $suspended_url[$i];
        $title = $suspended_title[$i];
        print HTML &make_link($SuspendedTemplate,$url,$title,""),"\n";
      }
      print HTML "<!--/Suspended-->"; # replace due to split
      print HTML $part4;
      close (HTML);
  
    } else { # create the file
#      print "make new weekly file.\n" if defined($v_dbg);
      open (HTML,'>'.$qid.$file) || die "Can't open weekly output file.\nReason: $!\n";
      print HTML $sTitle;
      print HTML "<!-- created by AutoSearch.pl by wls -->\n";
      print HTML "<!--Top-->\n$WeeklyTop<!--/Top-->\n";
    
      # output weekly search status: appended
      $n = $#new_weekly_url + 1;
      # always do the heading
      print HTML "<!--AppendedHeading\n$AppendedHeading/AppendedHeading-->\n";
      print HTML &format_link($AppendedHeading,"DATE","$now") if $n;
      print HTML "<!--AppendedTemplate\n$AppendedTemplate/AppendedTemplate-->\n";
      $section = "Appended"; # the section of the file/output.
      print HTML "<!--$section-->\n";
      # format each unique result.
      for my $i (0..$n-1)
        {
        $url = $new_weekly_url[$i];
        $title = $new_weekly_title[$i];
        $description = $new_weekly_description[$i];
        my $sHTML = &make_link($AppendedTemplate,$url,$title,$description)."\n";
        print HTML $sHTML;
        $sEmail .= $sHTML;
        } # for $i
      print HTML $Appended;
      print HTML "<!--/$section-->\n\n";

      # output weekly search status: suspended
      $n = $#suspended_url + 1;
      # always do the heading
      print HTML "<!--SuspendedHeading\n$SuspendedHeading/SuspendedHeading-->\n";
      print HTML &format_link($SuspendedHeading,"DATE","$now") if $n;
      print HTML "<!--SuspendedTemplate\n$SuspendedTemplate/SuspendedTemplate-->\n";
      $section = "Suspended"; # the section of the file/output.
      print HTML "<!--$section-->\n";
      for ($i=0; $i < $n; $i++) {
        $url = $suspended_url[$i];
        $title = $suspended_title[$i];
        print HTML &make_link($SuspendedTemplate,$url,$title,""),"\n";
      }
      print HTML $Suspended;
      print HTML "<!--/$section-->\n\n";
  
      print HTML "<!--Bottom-->\n$WeeklyBottom<!--/Bottom-->\n";
      close (HTML);
    }
  } else {
#    print "no weekly changes required.\n" if defined($v_dbg);
  }

# now write the new index file.
# create the index.html output file
  my($key);
  open (HTML,'>'.$qid.'index.html') || die "Can't open summary output file.\nReason: $!\n";
  print HTML "<Title> Summary of Search results for $SummaryQuery</Title>\n";
  print HTML "<!-- created by AutoSearch.pl by wls -->\n";
  print HTML "<!--Top-->\n$SummaryTop<!--/Top-->\n";
  print HTML "<!--Query{$SummaryQuery}/Query-->\n";
  print HTML "<!--SearchEngine{$SummarySearchEngine}/SearchEngine-->\n" if ($SummarySearchEngine);
  foreach $key (keys (%{$query_options})) {
#    print "option::$key=$query_options->{$key}\n";
    print HTML "<!--QueryOptions{$key\=$query_options->{$key}\}QueryOptions-->\n";
  }
  print HTML "<!--URLFilter{$SummaryURLFilter}/URLFilter-->\n" if ($SummaryURLFilter);
  print HTML "\n";
# output summary of updated unique findings
  print HTML "<!--SummaryHeading\n$SummaryHeading/SummaryHeading-->\n";
  print HTML &format_link($SummaryHeading,"DATE","$now");
  print HTML "<!--SummaryTemplate\n$SummaryTemplate/SummaryTemplate-->\n";
  $section = "Summary"; # the section of the file/output.
  print HTML "<!--$section-->\n";
  if ($#new_weekly_url < 0) { # it has't changed; just re-cycle it.
    print HTML $Summary;
  } else {
#   format each unique result.
#    $description = "";
    $n = $#weekly_url + 1;
    for ($i=0; $i < $n; $i++) {
      $url = $weekly_url[$i];
      $title = $weekly_title[$i];
      print HTML &make_link($SummaryTemplate,$url,$title,""),"\n";
    }
  }
# output daily results status (none or ptr to new file).
  print HTML "<!--/$section-->\n\n";
  print HTML "<!--WeeklyHeading\n$WeeklyHeading/WeeklyHeading-->\n";
  print HTML &format_link($WeeklyHeading,"DATE","$now");
  print HTML "<!--WeeklyTemplate\n$WeeklyTemplate/WeeklyTemplate-->\n";
  $section = "Weekly"; # the section of the file/output.
  print HTML "<!--$section-->\n";
  # report errors FIRST.
  if ($hits == 0) {
    my($response) = $search->response();
    if ($response->is_success) { # dbg message, normally we're quiet
#      print HTML "AutoSearch Warning: Empty Results Set. <br>\n";
    } else { # SearchEngine error message:
      print HTML "AutoSearch Error: " . http_error_as_nice_string($response) . "<br>\n";
    }
  }
  # let's use reverse chronological order.
  # update the 'weekly' status:
  if ($changes) { # there were changes.
    # second run today?
    if ($Weekly =~ m/^No unique results found for(.*)$today/i) { # yes
#      print "change 'No' to 'Yes'\n";
      # change No to Yes.
      # the first line SHOULD be today's, assume so.
      # delete first line of $Weekly and write new link
      my($junk);
      ($junk,$Weekly) = split (/\n/,$Weekly,2); # split off first line
      print HTML "Web search results for <a href=\"$file\">search on ",$today,"</a><br>\n"; 
    } elsif ($Weekly =~ m/^Web search results for(.*)$today/) { # yes we already have a link, leave it.
#      print "leave 'Yes'\n";
    } else { # no link for today of any kind. add one.
#      print "insert 'Yes'\n";
      print HTML "Web search results for <a href=\"$file\">search on ",$today,"</a><br>\n"; 
    }
  } else { # no changes.
    # second run today?
    if ($Weekly =~ m/^No unique results found for(.*)$today/i) { # yes
#      print "leave 'No'\n";
    } elsif ($Weekly =~ m/^Web search results for(.*)$today/) { # yes we already have a link, leave it.
#      print "leave 'Yes'\n";      # do nothing, still no results.
    } else { # no results, add a line.
#      print "insert 'No'\n";
      print HTML "No unique results found for search on ",$today,"<br>\n";
    }
  }
  print HTML $Weekly;
  print HTML "<!--/$section-->\n\n";

  print HTML "<!--Bottom-->\n$SummaryBottom<!--/Bottom-->\n";
  close (HTML);

  if ($opts{'m'} && ($sEmail ne ''))
    {
    $sEmail = <<"EMAILEND";
<HTML>
<HEAD>
$sTitle
</HEAD>
<BODY>
<h2>The following URLs are new matches for your query '$SummaryQuery':</h2>
<P>
$sEmail
</BODY>
</HTML>
EMAILEND
    my $oMsg = MIME::Lite->new(
                               To => $opts{'m'},
                               Subject => "Results of AutoSearch query '$SummaryQuery'",
                               Type => 'text/html',
                               Data => $sEmail,
                          );
    my $res = $oMsg->send;
    } # if
  } # main

#=head1 NAME
#
#check_index_file($qid) -  insure the index.html file exists.
#
#
#=head1 DESCRIPTION
#
#If qid/index.html exists just return.
#Else create qid/ if necessary and call make_index
#to make the F<index.html> file.
#
#=cut

sub check_index_file {
  my($qid) = @_;
  # do we have the necessary infrastructure?
  if (open (FIRST,'<'.$qid."index.html") ) { # yes
    # OK, close it.
    close (FIRST);
  } else { # no, make dir.
    if (mkdir ($qid, 0755) ) {
      if ($! =~ m/file exists/i) { # already done
        die "Can't create directory $qid.\nReason $!";
      }
    }
    chmod 0755, $qid || die "Can't chmod directory $qid.\nReason $!";
    &make_index($qid);
  }
  print "index.html exists, " if $main::v_dbg;
}

#=head1 NAME
#
#check_date_file($qid) -  insure the date.html file exists.
#
#
#=head1 DESCRIPTION
#
#
#If qid/date.html exists just return.
#Else create qid/ if necessary and call make_date
#to make the F<date.html> file.
#
#=cut

sub check_date_file {
  my($qid,$qn,$qs) = @_;
  # do we have the necessary infrastructure?
  if (open (FIRST,'<'.$qid."date.html") ) { # yes
    # OK, close it.
    close (FIRST);
  } else { # no, make dir.
    if (mkdir ($qid, 0755) ) {
      if ($! =~ m/file exists/i) { # already done
        die "Can't create directory $qid.\nReason $!";
      }
    }
    chmod 0755, $qid || die "Can't chmod directory $qid.\nReason $!";
    &make_date($qid,$qn,$qs);
  }
  print "date exists, " if $main::v_dbg;
}

#=head1 NAME
#
#read_query($prompt) -  read a string from STDIN.
#
#
#=head1 DESCRIPTION
#
#read STDIN, with a prompt and backspace editing, until <return>
#
#=cut

sub read_query {
 my($prompt) = @_;
 my($query) = '';
 my($c) = '';
 my($oldfh) = select(STDOUT); $| =1; select ($oldfh);
 print $prompt;
 while (read(STDIN,$c,1)) { # get a byte.
#   printf "%02x",ord($c);
   last if $c eq "\x0a";
   if ($c eq "\x08") {
     chop ($query);
     next;
   } else {
     $query .= $c;
   }
 }
# print "\ni see $query\n";
 return ($query);
}

#=head1 NAME
#
#read_query_list($prompt) -  read a list from STDIN.
#
#
#=head1 DESCRIPTION
#
#read STDIN, with a prompt and backspace editing, until <blank-line>
#
#=cut

sub read_query_list {
 my($prompt) = @_;
 my(@query_list);
 my($s);
 while (1) {
   $s = &read_query($prompt);
   last unless ($s);
   push(@query_list,$s);
 }
# print "\ni see $query_list\n";
 return (@query_list);
}

#=head1 NAME
#
#C<format_link($template,$field,$data)> -  create hyper links from a template.
#
#
#=head1 DESCRIPTION
#
#Replace the $field with $data in the $template given.
#For example:
#	print C<&format_link("Hello place.\n","place","world");>
#produces
#	Hello world.
#
#Used to replace default strings in the default documents with
#user supplied information.
#
#=cut

# format by text replacement.
sub format_link {
  my ($unformated,$field,$data) = @_;
  my ($temp) = $unformated; # start with unformated string.
  $temp =~ s/$field/$data/; # make the replacement.
  return ($temp);
}

#=head1 NAME
#
#C<make_link($template,$url,$title,$description)> -  create url.
#
#
#=head1 DESCRIPTION
#
#Replace the URL, TITLE, and DESCRIPTION  with $url, $title, and
#$description (respectively) in the $template given.
#
#Used to convert a url template to a hyper-link with title and description.
#
#=cut

sub make_link {
  my ($template,$url,$title,$description) = @_;
  my ($link) = $template;
  $link =~ s/URL/$url/ if defined($url);
  $link =~ s/TITLE/$title/ if defined($title);
  $link =~ s/DESCRIPTION/$description/ if defined($description);
  return ($link);
}

#=head1 NAME
#
#C<make_no_link($template,$url,$title,$description)> -  create url.
#
#
#=head1 DESCRIPTION
#
#Replace the URL, TITLE, and DESCRIPTION  with $url, $title, and
#$description (respectively) in the $template given.
#
#Used to convert a url template to a url with title and description.
#
#=cut

sub make_no_link {
  my ($template,$url,$title,$description) = @_;
  my ($link) = $template;
  $link =~ s/URL/$url/ if defined($url);
  $link =~ s/TITLE/$title/ if defined($title);
  $link =~ s/DESCRIPTION/$description/ if defined($description);
  return ($link);
}

#=head1 NAME
#
#C<get_weekly_parts($qid)> -  break input file into sub-fields.
#
#
#=head1 DESCRIPTION
#
#Used to convert an input file into the data elements, template and headings
#required to build nice looking web pages.
#
#=cut

#
# read top.html to get the basic format of the web pages.
# parts include Top, Topic, Appended, Suspended, Bottom
# sub-parts include Heading, Template, actual contents.
# these objects are identified and extracted from the
# complete file.  The format for all derived documents
# is determined by this file.  How the objects are combined
# to created dervied pages is determined by the software
# enclosed here-in.
#
sub get_weekly_parts {
  my($qid) = @_;
  $/ = undef(); # enable paragraph mode.
  my($Top,$Bottom);
  my($AppendedHeading,$AppendedTemplate,$Appended);
  my($SuspendedHeading,$SuspendedTemplate,$Suspended);
  open (PARTS,'<'.$qid.'date.html') || die "Can't open first date input file.\nReason: $!\n";
  my($part) = <PARTS>;
  close (PARTS);
#  print "Part:\"$part\"\n";

  $Top = &get_pair_part($part,"Top");

  $AppendedHeading = &get_part($part,"AppendedHeading");
  $AppendedTemplate = &get_part($part,"AppendedTemplate");
  $Appended = &get_pair_part($part,"Appended");

  $SuspendedHeading = &get_part($part,"SuspendedHeading");
  $SuspendedTemplate = &get_part($part,"SuspendedTemplate");
  $Suspended = &get_pair_part($part,"Suspended");

  $Bottom = &get_pair_part($part,"Bottom");
  return($Top,
         $AppendedHeading,$AppendedTemplate,$Appended,
         $SuspendedHeading,$SuspendedTemplate,$Suspended,
	 $Bottom);
}

#=head1 NAME
#
#C<get_summary_parts($qid)> -  break input file into sub-fields.
#
#
#=head1 DESCRIPTION
#
#Used to convert an input file into the data elements, template and headings
#required to build nice looking web pages.
#
#=cut

sub get_summary_parts {
  my($qid) = @_;
  $/ = undef(); # enable paragraph mode.
  my($Top,$Query,$SearchEngine,@QueryOptions,$URLFilter,$Bottom);
  my($SummaryHeading,$SummaryTemplate,$Summary);
  my($WeeklyHeading,$WeeklyTemplate,$Weekly);
  open (PARTS,'<'.$qid.'index.html') || die "Can't open index.html input file.\nReason: $!\n";
  my($part) = <PARTS>;
  close (PARTS);
#  print "Part:\"$part\"\n";

  $Top = &get_pair_part($part,"Top");
  $Query = &get_inline_part($part,"Query");
  $SearchEngine = &get_inline_part($part,"SearchEngine");
  # get array of key=value pairs
  @QueryOptions = &get_inline_list($part,"QueryOptions");
  $URLFilter = &get_inline_part($part,"URLFilter");

  $SummaryHeading = &get_part($part,"SummaryHeading");
  $SummaryTemplate = &get_part($part,"SummaryTemplate");
  $Summary = &get_pair_part($part,"Summary");

  $WeeklyHeading = &get_part($part,"WeeklyHeading");
  $WeeklyTemplate = &get_part($part,"WeeklyTemplate");
  $Weekly = &get_pair_part($part,"Weekly");

  $Bottom = &get_pair_part($part,"Bottom");
  return($Top,$Query,$SearchEngine,$URLFilter,
         $SummaryHeading,$SummaryTemplate,$Summary,
         $WeeklyHeading,$WeeklyTemplate,$Weekly,
	 $Bottom,@QueryOptions);
}

#=head1 NAME
#
#C<get_pair_part($part,$mark)> -  locate and return sub-fields.
#
#
#=head1 DESCRIPTION
#
#Use regular expressions to locate <!--$mark--> and <!--/$mark--> and
#return everything in between (including <return>s).
#
#=cut

# these objects are surrounded by <!--x--> <!--/x--> comments
# to be easily recognized; but always display..
sub get_pair_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark-->\n(.*)<!--/$mark-->,s) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  # print "Warning: can't find <!--$mark--> ... <--/$mark-->\n" if defined($v_dbg);
  return ("");
}

#=head1 NAME
#
#C<get_part($part,$mark)> -  locate and return sub-fields.
#
#
#=head1 DESCRIPTION
#
#Use regular expressions to locate <!--$mark\n and /$mark--> and
#return everything in between (including <return>s).
#
#=cut

# these objects are surrounded by similiar matching x /x marks.
# these objects are actually comments and won't be seen unless
# modified.
sub get_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark\n(.*)/$mark-->,s) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  # print "Warning: can't find <!--$mark\\n ... /$mark-->\n" if defined($v_dbg);
  return ("");
}

#=head1 NAME
#
#C<get_inline_part($part,$mark)> -  locate and return sub-fields.
#
#
#=head1 DESCRIPTION
#
#Use regular expressions to locate <!--$mark{ and }/$mark--> and
#return everything in between.
#
#=cut

# these objects are surrounded by similiar matching x /x marks.
# these objects are actually comments and won't be seen unless
# modified.
sub get_inline_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark\{(.*)\}/$mark-->,s) {
#    print "inline $mark: \{$1\}\n";
    return ($1);
  }
  # print "Warning: can't find <!--$mark\{ ... \}/$mark-->\n" if defined($v_dbg);
  return ("");
}


#=head1 NAME
#
#C<get_inline_list($part,$mark)> -  locate and return sub-fields.
#
#
#=head1 DESCRIPTION
#
#Use regular expressions to locate multiple occurances of 
#<!--$mark{ and }/$mark--> and return them as a list.
#
#=cut

# these objects are surrounded by similiar matching x /x marks.
# these objects are actually comments and won't be seen unless
# modified.
sub get_inline_list {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark\{(.*)\}/$mark-->,s) {
    my(@PARTS) = split(/\n/, $part);
    my(@LINES) = grep(m,<!--$mark\{(.*)\}/$mark-->,s, @PARTS);
    my(@LIST,$is);
    foreach (@LINES) {
      next unless ($_ =~ m,<!--$mark\{(.*)\}/$mark-->,s);
#      print "inline $mark: \{$1\}\n";
      push (@LIST,$1);
    }
    return (@LIST);
  }
  # print "Warning: can't find <!--$mark\{ ... \}/$mark-->\n" if defined($v_dbg);
  return ("");
}

#=head1 NAME
#
#C<make_index($qid)> -  make working copy of F<index.html>.
#
#
#=head1 DESCRIPTION
#
#Create F<qid/index.html> from either F<first_index.html>
#or from 'memory'.
#
#=cut

# check the root directory for default first_index file;
# else make one of our own.
sub make_index {
  my($qid) = @_;
  open (INDEX,'>'.$qid."index.html") || die "Can't create index.html in $qid\nReason $!";
  # copy user-provided file...
  if (open (DEFAULT,'<'.$qid."../first_index.html") ) { # look for a default
    # copy in default provided by user.
    while (<DEFAULT>) {
      print INDEX $_;
    }
    close (DEFAULT) || die "Can't close default index.html file.\nReason:$!";
    close (INDEX) || die "Can't close index.html file.\nReason:$!";
    return;
  } 
  # or OUR provided file
  my($it) = <<EOF;
<HEAD>
<Title> index.html empty page to establish summary file format </Title>
</HEAD>

<BODY>
<!--Top-->
<!--Place the html to make your page start to look nice here-->
<!--In the next line place the pretty name of the query.-->
<h1>AutoSearch WEB Searching</h1>
<!--/Top-->

<!--In the next line place the actual query.-->
<!--Query{ask user}/Query-->
<!--In the next line place the actual search engine.-->
<!--SearchEngine{AltaVista}/SearchEngine-->
<!--In the next line(s) place the query/search engine specific options.-->
<!--QueryOptions{}/QueryOptions-->
<!--In the next line place the actual url filter.-->
<!--URLFilter{}/URLFilter-->

<!--SummaryHeading
<h3>Summary of WEB search results</h3><p>
/SummaryHeading-->

<!--The list of unique 'hits' including a url and title.-->
<!--SummaryTemplate
<a href="URL">TITLE</a><br>
/SummaryTemplate-->

<!--Summary-->
<!--the list of unique 'hits' goes here.-->
<!--/Summary-->

<!--WeeklyHeading
<hr>
<h3>Weekly Search Results</h3><p>
/WeeklyHeading-->

<!--The list of 'hits' including a url and title.-->
<!--WeeklyTemplate
<a href="URL">TITLE</a><br>
/WeeklyTemplate-->

<!--Weekly-->
<!--the list of weekly results goes here.-->
<!--/Weekly-->

<!--Bottom-->
<!--Place the html to make your page finish up sharply here-->
<p>
Last modified October 17, 1996.
<!--/Bottom-->
</BODY>
EOF

  print INDEX $it;
  close(INDEX);
}

#=head1 NAME
#
#make_date($qid) -  make working copy of F<date.html>.
#
#
#=head1 DESCRIPTION
#
#Create F<qid/date.html> from either F<first_date.html>
#or from 'memory'.
#
#=cut

# check the root directory for default first_date file;
# else make one of our own.
sub make_date {
  my($qid,$qn,$qs) = @_;
  open (FIRST,'>'.$qid."date.html") || die "Can't create date in $qid\nReason $!";
  # copy user-provided file...
  if (open (DEFAULT,'<'.$qid."../first_date.html") ) { # look for a default
    # copy in default provided by user.
    while (<DEFAULT>) {
      s/{ask user}/\{$qs\}/ if (m,Query\{ask user\}/Query,);
      s/AutoSearch WEB Searching/$qn/ if (m,AutoSearch WEB Searching,);
      print FIRST $_;
    }
    close (DEFAULT) || die "Can't close default first_date.html file.\nReason:$!";
    close (FIRST) || die "Can't close date.html file.\nReason:$!";
    return;
  } 
  # or OUR provided file
  my($it) = <<EOF;
<HEAD>
<Title> first_date.html empty page to establish weekly file format </Title>
</HEAD>

<BODY>
<!--Top-->
<!--Place the html to make your page start to look nice here-->
<!--In the next line place the pretty name of the query.-->
<h1>AutoSearch WEB Searching</h1>
<!--/Top-->

<!--The Title of the search results. 'DATE' will be replaced with the date.-->
<!--AppendedHeading
<h3>Web Search Results for DATE</h3><p>
/AppendedHeading-->

<!--The list of 'hits' including a url, title and description.-->
<!--AppendedTemplate
<a href="URL">TITLE</a><br>
<blockquote>
DESCRIPTION
</blockquote>
/AppendedTemplate-->

<!--Appended-->
<!--the list of 'hits' goes here.-->
<!--/Appended-->

<!--SuspendedHeading
<hr>
<h3>URLs Apparently Suspended</h3><p>
/SuspendedHeading-->

<!--The list of 'misses' only the title.-->
<!--SuspendedTemplate
TITLE<br>
/SuspendedTemplate-->

<!--Suspended-->
<!--the list of 'misses' goes here.-->
<!--/Suspended-->

<!--Bottom-->
<!--Place the html to make your page finish up sharply here-->
<p>
Web searches maintained by <a href="http://www.isi.edu/lsam/autosearch/index.html">AutoSearch</a>.
<!--/Bottom-->
</BODY>
EOF

  $it =~ s/{ask user}/\{$qs\}/ if ($it =~ m,Query\{ask user\}/Query,);
  $it =~ s/AutoSearch WEB Searching/$qn/ if ($it =~ m,AutoSearch WEB Searching,);

  print FIRST $it;
  close(FIRST);
}

sub time_now {
    return strftime("%m/%d/%Y %H:%M:%S", localtime(time));
}

sub time_today {
    return strftime("%b %d, %Y", localtime(time));
}

sub time_file_of_the_day_numeric {
    return strftime("%Y%m%d", localtime(time));
}


sub http_error_as_nice_string {
    my($response) = @_;
    my($message) = $response->message();
    my($code) = $response->code();
    chomp($message);
    return "$message (code $code)";
}

sub add_to_hash
  {
  # This is a bit of a hack.  A set of CGI options is not strictly a
  # hash, because multiple values for the same key can be specified.
  # To get around this, we rely on the fact that this hash of options
  # is only used to construct a CGI parameter list.  If we see
  # multiple values for the same key, we append the multiple values
  # onto the value of the key in CGI '?key=value' format.
  my ($key, $value, $hashref) = @_;
  if (exists($hashref->{$key}) && $hashref->{$key} ne '')
    {
    # There was already an option of this key given; append
    # multiple values as CGI arguments:
    $hashref->{$key} .= "&$key=$value";
    } # if exists
  else
    {
    # This is the only instance of this key; just insert the
    # hash value:
    $hashref->{$key} = $value;
    }
  } # add_to_hash
