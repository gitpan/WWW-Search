#!/home/johnh/BIN/perl5 -w

#
# AutoSearch.pl
# Copyright (C) 1996 by USC/ISI
# $Id: AutoSearch.pl,v 1.1 1996/10/09 20:21:38 wls Exp $
#
# Copyright (c) 1996 University of Southern California.
# All rights reserved.                                            
#                                                                
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation, advertising
# materials, and other materials related to such distribution and use
# acknowledge that the software was developed by the University of
# Southern California, Information Sciences Institute.  The name of the
# University may not be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 


my($www) = "/nfs/web/htdocs/div7/lsam/ib/wls/"; # the base of the web files

my($query) = '"lsam replication"';

# later get this from ??
my($queries) = '"lsam replication"
+"john heidemann" + work
caching
load balancing
persistent connection
web performance
';

sub usage {
    print STDERR <<END;
usage: $0 query
Make the query to Alta Vista.
END
    exit 1;
}

use strict;

&usage if ($#ARGV == -1);
&usage if ($#ARGV >= 0 && $ARGV[0] eq '-?');

BEGIN {
    # next line is a development hack
    push (@INC, "..");
}

use CLIENTS::Time;
use WWW::Search;
use WWW::Search::AltaVista;

my($time) = new CLIENTS::Time;

if ($#ARGV >= 0) {
  &main(join(" ", @ARGV));
} else {
#  foreach (split(/\n/, $queries)) {
  foreach (split(/\n/, $query)) {
    &main ($_);
  }
}
exit 0;

########
# subs #
########

# submit a search to alta vista and build output file.
#
sub main {
  my($query_dir) = @_;
  my($dbg_search) = 0;
  print "query directory: {$query_dir}, ";
  my($qdir) = $query_dir.'/';
  # do we have the necessary infrastructure?
  if (open (FIRST,'<'.$www.$qdir."first_date.html") ) { # yes
    # OK, close it.
    close (FIRST);
  } else { # no, make dir.
    if (mkdir ($www.$qdir, 0755) ) {
      if ($! =~ m/file exists/i) { # already done
        die "Can't create directory $qdir.\nReason $!";
      }
    }
    chmod 0755, $www.$qdir || die "Can't chmod directory $qdir.\nReason $!";
    &make_first_date($www,$qdir);
  }
  print "first_date exists, ";
  my($now) = $time->now;
  print "Now = ", $now, "\n";
  print "Daily file name = ",  $time->file_of_the_day_numeric, "\n" if $dbg_search;
  print "Timely file name = ", $time->file_of_the_time, "\n" if $dbg_search;

  my($Top,$Query,$WeeklyHeading,$WeeklyTemplate,$Weekly,$Bottom) = &get_weekly_parts($www,$qdir);

  if ($Query =~ m/ask user/i) {
    my($QueryName,$QueryString);
    $QueryName = &read_query("Please enter a Query Name:");
    $Top =~ s/AutoSearch WEB Searching/$QueryName/i;
    $QueryString = &read_query("Please enter a Query String:");
    $Query = $QueryString;
  }
  print "Query is \"$Query\"\n";
# search AltaVista
  my($search) = new WWW::Search::AltaVista;
# submit search
  $search->native_query(WWW::Search::escape_query($Query));
# examine search results
  my($next_result,$url,$description,$title,$q);
  $q = $Query;
  $q =~ tr / /_/; # replace spaces
  $q =~ tr/"//d; # remove quotes.
  print "clean query is \"$q\"\n" if $dbg_search;
# create the output file
  open (HTML,'>'.$www.$qdir.$time->file_of_the_day_numeric.'.html') || die "Can't open daily output file.\nReason: $!\n";
  print HTML "<Title> Search results for $Query as of $now </Title>\n";
  print HTML "<!-- created by AutoSearch.pl by wls -->\n";
  print HTML "<!--Top-->\n$Top<!--/Top-->\n";
  print HTML "<!--Query{$Query}/Query-->\n\n";
  print HTML "<!--WeeklyHeading\n$WeeklyHeading/WeeklyHeading-->\n";
  print HTML &format_link($WeeklyHeading,"DATE","$now");
  print HTML "<!--WeeklyTemplate\n$WeeklyTemplate/WeeklyTemplate-->\n";
  my($section) = "Weekly"; # the section of the file/output.
  print HTML "<!--$section-->\n";
  print HTML $Weekly;
# format each responce.
  while ($next_result = $search->next_result()) {
    $url = $next_result->url;
    # let's not display references to our own pages.
    next if $url =~ m,www\.isi\.edu/div7/ib/(.+)/$q(.+)\.html$,o;
    $title = $next_result->title;
    $description = $next_result->description;
    print "\nurl: ", $url, "\n" if $dbg_search;
    print "description: ", $description, "\n" if $dbg_search;
    print "title: ", $title, "\n" if $dbg_search;
    print HTML &make_link($WeeklyTemplate,$url,$title,$description),"\n";
  }
  print HTML "<!--/$section-->\n\n";
  print HTML "<!--Bottom-->\n$Bottom<!--/Bottom-->\n";
  close (HTML);
}

sub read_query {
 my($prompt) = @_;
 my($query) = '';
 my($c) = '';
 my ($oldfh) = select(STDOUT); $| =1; select ($oldfh);
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

# format by text replacement.
sub format_link {
  my ($unformated,$field,$data) = @_;
  my ($temp) = $unformated; # start with unformated string.
  $temp =~ s/$field/$data/; # make the replacement.
  return ($temp);
}

sub make_link {
  my ($template,$url,$title,$description) = @_;
  my ($link) = $template;
  $link =~ s/URL/$url/;
  $link =~ s/TITLE/$title/;
  $link =~ s/DESCRIPTION/$description/;
  return ($link);
}

#
# read top.html to get the basic format of the web pages.
# parts include Top, Topic, Summary, Results, Weekly, Bottom
# sub-parts include Heading, Template, actual contents.
# these objects are identified and extracted from the
# complete file.  The format for all derived documents
# is determined by this file.  How the objects are combined
# to created dervied pages is determined by the software
# enclosed here-in.
#
sub get_weekly_parts {
  my($www,$qdir) = @_;
  $/ = undef(); # enable paragraph mode.
  my($Top,$Query,$Bottom);
  my($WeeklyHeading,$WeeklyTemplate,$Weekly);
  open (PARTS,'<'.$www.$qdir.'first_date.html') || die "Can't open top input file.\nReason: $!\n";
  my($part) = <PARTS>;
  my($junk);
  close (PARTS);
#  print "Part:\"$part\"\n";

  $Top = &get_pair_part($part,"Top");
  $Query = &get_inline_part($part,"Query");
  $Query =~ tr/{}//d; # remove braces

  $WeeklyHeading = &get_part($part,"WeeklyHeading");
  $WeeklyTemplate = &get_part($part,"WeeklyTemplate");
  $Weekly = &get_pair_part($part,"Weekly");

  $Bottom = &get_pair_part($part,"Bottom");
  return($Top,$Query,$WeeklyHeading,$WeeklyTemplate,$Weekly,$Bottom);
}

# these objects are surrounded by <!--x--> <!--/x--> comments
# to be easily recognized; but always display..
sub get_pair_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark-->\n(.*)<!--/$mark-->,s) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  return (undef);
}

# these objects are surrounded by similiar matching x /x marks.
# these objects are actually comments and won't be seen unless
# modified.
sub get_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark\n(.*)/$mark-->,s) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  return (undef);
}

# these objects are surrounded by similiar matching x /x marks.
# these objects are actually comments and won't be seen unless
# modified.
sub get_inline_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark(.*)/$mark-->,s) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  return (undef);
}

sub wls_get_pair_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark-->\n([\x01-\x7f]*?)<!--/$mark-->,) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  return (undef);
}

sub wls_get_part {
  my($part,$mark) = @_;
  if ($part =~ m,<!--$mark\n([\x01-\x7f]*?)-->,) {
#    print "$mark: \"$1\"\n";
    return ($1);
  }
  return (undef);
}

# check the root directory for default first_date file;
# else make one of our own.
sub make_first_date {
  my($www,$qdir) = @_;
  open (FIRST,'>'.$www.$qdir."first_date.html") || die "Can't create first_date in $www.$qdir\nReason $!";
  # copy use-provided file...
  if (open (DEFAULT,'<'.$www."first_date.html") ) { # look for a default
    # copy in default provided by user.
    while (<DEFAULT>) {
      print FIRST $_;
    }
    close (DEFAULT) || die "Can't close default first_date file.\nReason:$!";
    close (FIRST) || die "Can't close first_date file.\nReason:$!";
    return;
  } 
  # or OUR provided file
  print FIRST <<EOF
<Title> first_date.html empty page to establish weekly file format </Title>
<!--Top-->
<!--Place the html to make your page start to look nice here-->
<!--In the next line place the pretty name of the query.-->
<h1>AutoSearch WEB Searching</h1>
<!--/Top-->

<!--In the next line place the actual query.-->
<!--Query{"ask user"}/Query-->

<!--The Title of the search results. 'DATE' will be replaced with the date.-->
<!--WeeklyHeading
<h3>Web Search Results for DATE</h3><p>
/WeeklyHeading-->

<!--The list of 'hits' including a url, title and description.-->
<!--WeeklyTemplate
<a href="URL">TITLE</a><br>
<blockquote>
DESCRIPTION
</blockquote>
/WeeklyTemplate-->

<!--Weekly-->
<!--the list of 'hits' goes here.-->
<!--/Weekly-->

<!--Bottom-->
<!--Place the html to make your page finish up sharply here-->
Last modified October 8, 1996.
<!--/Bottom-->
EOF
;

  close(FIRST);
}

