#!/usr/local/bin/perl -w

# NorthernLight.pm
# by Jim Smyser
# Copyright (C) 1996-1998 by USC/ISI
# $Id: NorthernLight.pm,v 1.4 1999/05/27 23:15:56 johnh Exp $
#
# Complete copyright notice follows below.
#

package WWW::Search::NorthernLight;


=head1 NAME

WWW::Search::NorthernLight - class for searching NorthernLight


=head1 SYNOPSIS

    use WWW::Search;
    my $oSearch = new WWW::Search('NorthernLight');
    my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
    $oSearch->native_query($sQuery);
    while (my $oResult = $oSearch->next_result()) {
        print $oResult->url, "\n";
    }
=head1 DESCRIPTION


This class is a NorthernLight specialization of WWW::Search.
It handles making and interpreting NorthernLight searches
F<http://www.northernlight.com>.

Northern Light supports full Boolean capability (AND,
OR, NOT), including parenthetical "expressions", in
all searches. There is no limit to the level of nesting
which you can use in a query.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 HOW DOES IT WORK?

C<native_setup_search> is called (from C<WWW::Search::setup_search>)
before we do anything.  It initializes our private variables (which
all begin with underscore) and sets up a URL to the first results
page in C<{_next_url}>.

C<native_retrieve_some> is called (from C<WWW::Search::retrieve_some>)
whenever more hits are needed.  It calls C<WWW::Search::http_request>
to fetch the page specified by C<{_next_url}>.
It then parses this page, appending any search hits it finds to
C<{cache}>.  If it finds a ``next'' button in the text,
it sets C<{_next_url}> to point to the page for the next
set of results, otherwise it sets it to undef to indicate we''re done.


=head1 BUGS

You bet! Although I think I have pointed them all out to NL
so there shouldn't now be any.

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism.

  Test cases:
 '+mrfglbqnx +NoSuchWord'          ---   no hits
 '+LSAM +replication'              ---   13 hits on one page
 '+Jabba +bounty +hunter +Greedo'  ---  138 hits on two pages


=head1 AUTHOR
This Backend will now be maintained and supported by Jim Smyser.

Flames to: <jsmyser@bigfoot.com>

C<WWW::Search::NorthernLight> was originally written by Andreas Borchert
based on C<WWW::Search::Excite>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=head1 VERSION HISTORY
1.03
Slight format change by NL that was making next page hits flakey
corrected. Misc. code clean up.

=cut
#'

#####################################################################
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.03';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search {
   my($self, $native_query, $native_options_ref) = @_;
   print STDERR "New NorthernLight.pm v1.03\n" if $self->{_debug};
   $self->{_debug} = $native_options_ref->{'search_debug'};
   $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
   $self->{_debug} = 0 if (!defined($self->{_debug}));

   $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
   $self->user_agent('non-robot');
   $self->{_next_to_retrieve} = 1;
   $self->{'_num_hits'} = 0;

   if (!defined($self->{_options})) {
     $self->{'search_base_url'} = 'http://www.northernlight.com';
     $self->{_options} = {
              'search_url' => 'http://www.northernlight.com/nlquery.fcg',
              'qr' => $native_query,
              'si' => '',
              'cb' => '0',
              'cc' => '',
              'us' => '025',
     };
		   }
   my $options_ref = $self->{_options};
   if (defined($native_options_ref))
     {
     # Copy in new options.
     foreach (keys %$native_options_ref)
       {
       $options_ref->{$_} = $native_options_ref->{$_};
       } # foreach
     } # if
   # Process the options.
   my($options) = '';
   foreach (sort keys %$options_ref)
     {
     # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
     next if (generic_option($_));
     $options .= $_ . '=' . $options_ref->{$_} . '&';
     }
   chop $options;
   # Finally figure out the url.
   $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
   } # native_setup_search

# private
sub native_retrieve_some
    {
    my ($self) = @_;
    print STDERR " *   Snap::native_retrieve_some()\n" if $self->{_debug};

    # Fast exit if already done:
    return undef if (!defined($self->{_next_url}));

    # If this is not the first page of results, sleep so as to not
    # overload the server:
    $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};

    # Get some if were not already scoring somewhere else:
    print STDERR " *   sending request (",$self->{_next_url},")\n" if $self->{_debug};
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success)
      {
      return undef;
      }
    $self->{'_next_url'} = undef;
    print STDERR " *   got response\n" if $self->{_debug};
    # parse the output
    my ($HEADER, $HITS, $START, $DESC, $SCORE) = qw(HE HI ST DE SC);
    my $hits_found = 0;
    my $state = $HEADER;
    my $hit = ();
    foreach ($self->split_lines($response->content()))
      {
     next if m@^$@; # short circuit for blank lines
     print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};
     if (m|(\d+) items|i) {
       print STDERR " number of pages line\n" if ($self->{_debug});
       $state = $START;
	#Establish a starting point past undesirable URLs that may get picked up
  } elsif ($state eq $START && m{<!-- result -->}i) {
		 $state = $HITS;
  } if ($state eq $HITS && m@<a href="(.*?)">(.*?)</a><br>@i) {
       print STDERR "hit url line\n" if 2 <= $self->{_debug};
       if (defined($hit))
         {
         push(@{$self->{cache}}, $hit);
         };
       $hit = new WWW::SearchResult;
       $hit->add_url($1);
       $hits_found++;
       $hit->title($2);
       $state = $SCORE;
   } elsif ($state eq $SCORE && m{<b>(\d+)+%}i) {
      $hit->score($1);
      $state = $DESC;

   } elsif ($state eq $DESC && m{-(.*)<br>}i) {
       print STDERR "description line\n" if 2 <= $self->{_debug};
       $hit->description($1);
       $state = $HITS;

      #This line now has to be more defined or NL will return same page
   } elsif ($state eq $HITS && m|<td valign=middle><a href="(.*)"><img src="(.*)alt="Next Page"></a></td>|i) {
       print STDERR "next line\n" if 2 <= $self->{_debug};
       my $sURL = $1;
       $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/first=(\d+)/;
       $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
       print STDERR " * next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
       $state = $HITS;
       } else {
       print STDERR "didn't match\n" if 2 <= $self->{_debug};
       }
  } if (defined($hit)) {
     push(@{$self->{cache}}, $hit);
     }
   return $hits_found;
   } # native_retrieve_some
 1;


