#!/usr/local/bin/perl -w

#
# HotBot.pm
# by Wm. L. Scheding
# Copyright (C) 1996 by USC/ISI
# $Id: HotBot.pm,v 1.4 1996/11/21 23:02:16 johnh Exp $
#
# Complete copyright notice follows below.
# 


package WWW::Search::HotBot;

=head1 NAME

WWW::Search::HotBot - class for searching HotBot 

=head1 DESCRIPTION

This class is an HotBot specialization of WWW::Search.
It handles making and interpreting HotBot searches
F<http://www.hotbot.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 HOW DOES IT WORK?

C<native_setup_search> is called before we do anything.
It initializes our private variables (which all begin with underscores)
and sets up a URL to the first results page in C<{_next_url}>.

C<native_retrieve_some> is called (from C<WWW::Search::retrieve_some>)
whenever more hits are needed.  It calls the LWP library
to fetch the page specified by C<{_next_url}>.
It parses this page, appending any search hits it finds to 
C<{cache}>.  If it finds a ``next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we're done.


=head1 BUGS

This module should support options.


=head1 AUTHOR

C<WWW::Search::HotBot> is by Wm. L. Scheding,
based on C<WWW::Search::AltaVista>.


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
#'

#
#  Test cases:
# ./hotbot.pl xxxasdf             --- no hits
# ./hotbot.pl 'scheding'          --- 373 hits
# ./hotbot.pl 'lsam replication'  --- 63 hits
# ./hotbot.pl 'replication'       --- 40,000+ hits
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
# $VERSION = 1.000;
@ISA = qw(WWW::Search Exporter);

use Carp ();
require WWW::SearchResult;

# from lynx #1
#       "http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
#	"&MT=" . $native_query .
#       "&SW=web&SM=MC&search=Submit%20search&MOD=0&OP=0" .
#       "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&smiley=&RD=AN&RG=NA&domain=" .
#       "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
#       "&OP=0&MOD=0&FS="; #>HotBot: replication#1 ( 1-10)
# from lynx #2
#       "http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
#       "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&RD=AN&RG=NA" .
#       "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
#       "&OP=0&MOD=0&SW=web&SM=MC" .
#	"&MT=" . $native_query .
#       "&base=0&totalhits=78641&next.x=Return%20next"; #>HotBot: replication#2 (11-20)
# from lynx #3
#       "http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
#       "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&RD=AN&RG=NA" .
#       "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
#       "&OP=0&MOD=0&SW=web&SM=MC" .
#	"&MT=" . $native_query .
#       "&base=10&totalhits=6429&next.x=Return%20next"; #>HotBot: replication#3 (21-30)
# from lynx #4
#       "http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
#       "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&RD=AN&RG=NA" .
#       "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
#       "&OP=0&MOD=0&SW=web&SM=MC" .
#	"&MT=" . $native_query .
#       "&base=20&totalhits=6429&next.x=Return%20next"; #>HotBot: replication#4 (31-40)

# private
sub native_setup_search
{
    my($self, $native_query) = @_;
    $self->user_agent();
    $self->{_next_to_retrieve} = 0;
    $self->{_base_url} = $self->{_next_url} =
        "http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
	"&MT=" . $native_query .
        "&SW=web&SM=MC&search=Submit%20search&MOD=0&OP=0" .
        "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&smiley=&RD=AN&RG=NA&domain=" .
        "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
        "&OP=0&MOD=0&FS="; # from lynx.
}

# private
sub native_retrieve_some
{
    my ($self) = @_;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    my($request) = new HTTP::Request('GET', $self->{_next_url});
    my($response) = $self->{user_agent}->request($request);
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    # parse the output
    # HotBot is trying to be too smart. if you come in with netscape,
    # it gives you a table/form interface; with lynx a simple text intfc.
    # we are pretending to be like lynx (that's what HotBot thinks).
    #
    # i had the code to play on the table interface almost working;
    # but gave up. $action, $hidden, etc. are leftovers.
#    my($TITLE, $FORM, $HEADER, $HITS, $BQ, $DESC, $TRAILER) = (1..10);
    my($TITLE, $HEADER, $HITS, $BQ, $DESC, $TRAILER) = (1..10);
    my($hits_found) = 0;
    my($state) = ($TITLE);
#    my($action,$action_name);
    my($name,$value);
    my($native_query);
    # i did get the code to read the hidden variable going; but went on to non table intfc.
#    my($hidden) = "";
    my($base,$total);
    my($hit) = ();
    foreach (split(/\n/, $response->content())) {
        next if m@^$@; # short circuit for blank lines
	if ($state == $TITLE && m@^<title>HotBot:\s+([^<]+)</title>$@i) {
            #"<title>HotBot: replication</title>"
#            print STDOUT "title:\"$_\"\n";
            $native_query = $1;
            $native_query =~ s/ /%20/g;
#	    $state = $FORM;
	    $state = $HEADER;
#	} elsif ($state == $FORM && m@^<form\s+action=\"([^"]+)\"\s+name=\"([^"]+)\">$@i) {
#          #"<form action="/search.html/IU0BeKgOCC935DC9C4ACA6716DD6115B28324907" name="HSQ">"
##            print STDOUT "form:\"$_\"\n";
#	    $action = $1;
#	    $action_name = $2;
#	    $state = $HEADER;
	} elsif ($state == $HEADER && m@^Returned\s+<b>(\d+)</b>\s+matches\.</blockquote>$@i) {
#            print STDOUT "header:\"$_\"\n";
            $total = $1;
	    $self->approximate_result_count($total);
	    $state = $HITS;
	} elsif ($state == $HITS && m@^<b>(\d+)\.\s+</b><a href=\"([^"]+)\">(.*)</a>@i) {
	    # "
#            print STDOUT "hit:\"$_\"\n";
            $base = $1 - 10;
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $hit = new WWW::SearchResult;
	    $hit->add_url($2);
	    $hits_found++;
	    $hit->title($3);
	    $state = $BQ;
	} elsif ($state == $BQ && m@^<blockquote>$@i) {
#            print STDOUT "blockquote:\"$_\"\n";
	    $state = $DESC;
	} elsif ($state == $DESC && m@^(.*)<p>$@i) {
#            print STDOUT "desc:\"$_\"\n";
	    $hit->description($1);
	    $state = $HITS;
	} elsif ($state == $HITS && m@<input name=\"([^"]+)\"\s+value=\"([^"]+)\"\s+type=\"submit\"\s+>@i) {
#            print STDOUT "next:\"$_\"\n"; # and or prev too.
	    $name = $1;
	    $value = $2;
            next if ($name =~ m/prev/i); # either wait for next; or quit on 'New Search'
	    # end, with a list of other pages to go to
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    # set up next page (using hidden fileds & compiling the form:)
#           chop ($hidden) if (substr($hidden,-1,1) eq '&');
#    	    my($relative_url) = sprintf("http://www.hotbot.com/search.html?%s",$hidden);
#	    print "URL:\"$relative_url\"\n";
            # <OR>
            # we have to build the URL, as we are faking a form
            # to wit:
#   URL:"http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
#       "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&RD=AN&RG=NA" .
#       "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
#       "&OP=0&MOD=0&SW=web&SM=MC" .
#       "&MT=replication&base=0&totalhits=73983&next.x=Return%20next"
    	    my($relative_url) = 
             "http://www.hotbot.com/search.html/IU0BfV5r318E4BCC8DBA81A045266430BFB7D0F4?_v=1.0" .
             "&date=WH&DR=newer&DM=1&DD=1&DY=96&DV=10&DU=years&RD=AN&RG=NA" .
             "&DC=10&FJS=off&FJA=off&FRA=off&FVI=off&FAC=off&FSW=off&FVR=off&FSU=off&FSM=off" .
             "&OP=0&MOD=0&SW=web&SM=MC" .
             "&MT=" . $native_query .
             "&base=" . $base .
             "&totalhits=" . $total .
             "&next.x=Return%20next";
#	    print "URL:\"$relative_url\"\n";
	    $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
	    $state = $TRAILER;
	} elsif ($state == $HITS && m@^(.+)>New Search</a>\s+-@i) {
#            print STDOUT "last:\"$_\"\n";
	    if (defined($hit)) {
	        push(@{$self->{cache}}, $hit);
	    };
	    $self->{_next_url} = undef;
	    $state = $TRAILER;
#	} elsif (m@^<input type=hidden\s+name=\"([^"]+)\"\s+value=\"([^"]+)\">$@i) {
##            print STDOUT "hidden1:\"$_\"\n";
#	    $name = $1;
#	    $value = $2;
#	    $hidden .= sprintf("%s=%s&",$1,$2);
#	} elsif (m@^<input type=hidden\s+name=\"([^"]+)\"\s+value=\"([^"]+)\"><input type=hidden\s+name=\"([^"]+)\"\s+value=\"([^"]+)\">$@i) {
##            print STDOUT "hidden2:\"$_\"\n";
#	    $hidden .= sprintf("%s=%s&",$1,$2);
#	    $hidden .= sprintf("%s=%s&",$3,$4);
#	} elsif (m@^(</table)>?<input type=hidden\s+name=\"([^"]+)\"\s+value=\"([^"]+)\"><input type=hidden\s+name=\"([^"]+)\"\s+value=\"([^"]+)\"><input type=hidden\s+name=\"([^"]+)\"\s+value=\"([^"]+)\">$@i) {
##            print STDOUT "hidden3:\"$_\"\n";
#	    $hidden .= sprintf("%s=%s&",$2,$3);
#	    $hidden .= sprintf("%s=%s&",$4,$5);
#	    $hidden .= sprintf("%s=%s&",$6,$7);
	} else {
#            print STDOUT "read:\"$_\"\n";
	};
    };
    if ($state != $TRAILER) {
	# end, no other pages (missed ``next'' tag)
	if (defined($hit)) {
	    push(@{$self->{cache}}, $hit);
	};
	$self->{_next_url} = undef;
    };

    # sleep so as to not overload hotbot
    $self->user_agent_delay if (defined($self->{_next_url}));

    return $hits_found;
}

1;
