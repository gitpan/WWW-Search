#!/usr/local/bin/perl -w

# NorthernLight.pm
# by Jim Smyser
# Copyright (C) 1996-1998 by USC/ISI
# $Id: NorthernLight.pm,v 1.3 1998/12/10 18:24:04 johnh Exp $
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

This is a overhaul on the work by Andreas Borchert. I have
not been able to get in touch with him so I went ahead and rebuilt
the script to work with NorthernLight. 

I can be flamed @ <jsmyser@bigfoot.com>

This class is a NorthernLight specialization of WWW::Search.
It handles making and interpreting NorthernLight searches
F<http://www.northernlight.com>.

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

Oh what the heck, till the author comes forward I will maintain
this backend. Flames to: <jsmyser@bigfoot.com>

C<WWW::Search::NorthernLight> was originally written by Andreas Borchert
based on C<WWW::Search::Excite>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=head1 VERSION HISTORY
1.2
This is my second re-write to account for lots of 
little annoying formatting changes.

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


# private
sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;

  my $DEFAULT_HITS_PER_PAGE = 25;
  # $DEFAULT_HITS_PER_PAGE = 30;  # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;


  $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
  $self->user_agent(1);

  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;

  # Remove '*' at end of query terms within the user's query.  If the
  # query string is not escaped (even though it's supposed to be),
  # change '* ' to ' ' at end of words and at the end of the string.
  # If the query string is escaped, change '%2A+' to '+' at end of
  # words and delete '%2A' at the end of the string.
  $native_query =~ s/(\w)\052\s/$1\040/g;
  $native_query =~ s/(\w)\052$/$1\040/g;
  $native_query =~ s/(\w)\0452A\053/$1\053/g;
  $native_query =~ s/(\w)\0452A$/$1/g;
  if (!defined($self->{_options})) {
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
  my $options = '';
  foreach (keys %$options_ref) 
    {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }

  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;

  # Set some private variables:
  $self->{_debug} = $options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
  $self->{_debug} = 0 if (!defined($self->{_debug}));
  } # native_setup_search

# private
sub native_retrieve_some
  {
  my ($self) = @_;
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  # Get some results, adhering to the WWW::Search mechanism:
  print STDERR " *   sending request (",$self->{_next_url},")\n" if $self->{'_debug'};
  my($response) = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    };
  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($HEADER, $CUSTOM, $HITS, $SCORE, $DESC, $TRAILER) = qw(HE CU HI SC DE TR);
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
  foreach ($self->split_lines($response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $HEADER && m{(\d+) items}i) {
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
     $state = $CUSTOM;
    } # we're in HEADER mode, and line has number of results
    elsif ($state eq $CUSTOM && m{<!-- result -->}i) {
      $state = $HITS;
      print STDERR "end of custom search folders\n" if 2 <= $self->{'_debug'};
    } elsif ($state eq $HITS &&	m{<a href="(.*?)">(.*?)</a><br>}) {
      print STDERR "hit found\n" if 2 <= $self->{'_debug'};
      push(@{$self->{cache}}, $hit) if defined($hit);
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hit->title($2);
      $self->{'_num_hits'}++;
      $hits_found++;
	  $state = $SCORE
    } elsif ($state eq $SCORE && m{<b>(\d+)+%}i) {
      $hit->score($1);
      $state = $DESC;
    } elsif ($state eq $DESC && m{-(.*)<br>}i) {
      print STDERR "hit percentage line\n" if 2 <= $self->{'_debug'};
      $hit->description($1);
      $state = $HITS;
    } elsif ($state eq $HITS && m{<table border=0>}i) {
      # End of hits  
      print STDERR "PARSE(HITS->TRAILER): $_\n\n" if ($self->{_debug} >= 2);
      $state = $TRAILER;
      #This line now has to be more defined or NL will return same page
    } elsif ($state eq $TRAILER && m{<td valign=middle><a href="(.*)"><img src="(.*)alt="Next Page"></a></td>}i) {
      # Finally, figure out the url.
      print STDERR " found next button, next url is $self->{_next_url}\n" if 2 <= $self->{'_debug'};
      $state = $TRAILER;
      }
    else
      {
      print STDERR "didn't match\n" if 2 <= $self->{'_debug'};
      }
    } # foreach line of query results HTML page

  if ($state ne $TRAILER)
    {
    # End, no other pages (missed some tag somewhere along the line?)
    $self->{_next_url} = undef;
    }
  if (defined($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    }
  return $hits_found;
  } # native_retrieve_some

1;


