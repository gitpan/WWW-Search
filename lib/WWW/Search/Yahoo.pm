#!/usr/local/bin/perl -w

#
# Yahoo.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996 by USC/ISI
# $Id: Yahoo.pm,v 1.5 1998/02/19 18:28:36 johnh Exp $
#


package WWW::Search::Yahoo;

=head1 NAME

WWW::Search::Yahoo - class for searching Yahoo 


=head1 DESCRIPTION

This class is an Yahoo specialization of L<WWW::Search>.
It handles making and interpreting Yahoo searches
F<http://www.yahoo.com>.

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



=head1 AUTHOR

As of 1998-02-02, C<WWW::Search::Yahoo> is maintained by Martin Thurn
(mthurn@irnet.rest.tasc.com).

C<WWW::Search::Yahoo> was originally written by Wm. L. Scheding,
based on C<WWW::Search::AltaVista>.


=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=cut

#
#  Test cases:
# ./yahoo.pl 'xxxxasdf'         --- no hits
# ./yahoo.pl 'repographics      --- 2 hits 
# ./yahoo.pl 'reprographics     --- 33 hits 
# ./yahoo.pl 'replication       --- 73 hits 
# ./yahoo.pl 'reproduction      --- 255 hits 
#



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;
  # print STDERR " * this is Martin's new Yahoo.pm!\n" if $self->{_debug};
  # Why waste time sending so many queries?  Do a whole lot all at once!
  my $DEFAULT_HITS_PER_PAGE = 100;
  # $DEFAULT_HITS_PER_PAGE = 10;   # for debugging
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;
  # Add one to the number of hits needed, because Search.pm does ">"
  # instead of ">=" on line 672!
  $self->{'maximum_to_retrieve'}++;
  # Divide the problem into N pages of K hits per page.
  my $iNumPages = int(0.999 + 
                      $self->{'maximum_to_retrieve'} / $self->{'_hits_per_page'});
  if (1 < $iNumPages)
    {
    $self->{'_hits_per_page'} = int($self->{'maximum_to_retrieve'} / $iNumPages);
    }
  else
    {
    $self->{'_hits_per_page'} = $self->{'maximum_to_retrieve'};
    }
  $self->{agent_e_mail} = 'mthurn@irnet.rest.tasc.com';

  # If we run as a robot, WWW::RobotRules fetches the
  # http://www.yahoo.com instead of http://www.yahoo.com/robots.txt,
  # and dumps a thousand warnings to STDERR.
  $self->user_agent('non-robot');

  $self->{_next_to_retrieve} = 0;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options})) 
    {
    $self->{_options} = {
                         'search_url' => 'http://search.yahoo.com/search',
                         'b' => $self->{_next_to_retrieve},
                         'h' => 's',
                         'n' => $self->{_hits_per_page},
                         'p' => $native_query,
                        };
    } # if
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
  foreach (keys %$options_ref) 
    {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  # Finally figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;

  $self->{_debug} = $options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
  $self->{_debug} = 0 if (!defined($self->{_debug}));
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  print STDERR " *   Yahoo::native_retrieve_some()\n" if $self->{_debug};
  
  # fast exit if already done
  return undef if (!defined($self->{_next_url}));
  
  # get some
  print STDERR " *   sending request (",$self->{_next_url},")\n" if $self->{_debug};
  my($response) = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    };
  
  $self->{'_next_url'} = undef;
  print STDERR " *   got response\n" if $self->{_debug};
  # parse the output
  my($HEADER, $HITS, $TRAILER) = qw(HE HI TR);
  my($hits_found) = 0;
  my($state) = ($HEADER);
  my($cite) = "";
  my($hit) = ();
  foreach (split(/\n/, $response->content())) 
    {
    next if m@^$@; # short circuit for blank lines
    print STDERR " * $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $HITS && s@^\s-\s(.+)(</UL>|<LI>)@$2@i)
      {
      # Actual line of input is:
      #  - Links to many other <b>Star</b> <b>Wars</b> sites as well as some cool original stuff.<LI><A HREF="http://www.geocities.com/Hollywood/Hills/3650/"><b>Star</b> <b>Wars</b>: A New Hope for the Internet</A>
      print STDERR "description line\n" if 2 <= $self->{_debug};
      my $sDescription = $1;
      $sDescription =~ s|</?b>||ig;
      $hit->description($sDescription) if defined($hit);
      # Don't change state, and don't go to the next line! The <LI> on
      # this line is the next hit!
      }
    if ($state eq $HEADER && m|^and\s<b>(\d+)</b>\s*$|)
      {
      print STDERR "header line\n" if 2 <= $self->{_debug};
      $self->approximate_result_count($1);
      $state = $HITS;
      }
    if ($state eq $HEADER && m|^<CENTER>Found\s<B>\d+</B>\sCategory\sand\s<B>(\d+)</B>\sSite\sMatches\sfor|i)
      {
      # Actual line of input is:
      # <CENTER>Found <B>15</B> Category and <B>1297</B> Site Matches for
      print STDERR "header line\n" if 2 <= $self->{_debug};
      $self->approximate_result_count($1);
      $state = $HITS;
      }
    elsif ($state eq $HITS &&
           m|<LI><A HREF=\042([^\042]+)\042>(.*)</A>|i) 
      {
      # Actual lines of input are:
      # <UL TYPE=disc><LI><A HREF="http://events.yahoo.com/Arts_and_Entertainment/Movies_and_Films/Star_Wars_Series/">Yahoo! Net Events: <b>Star</b> <b>Wars</b> Series</A>
      #  - Links to many other <b>Star</b> <b>Wars</b> sites as well as some cool original stuff.<LI><A HREF="http://www.geocities.com/Hollywood/Hills/3650/"><b>Star</b> <b>Wars</b>: A New Hope for the Internet</A>
      print STDERR "hit url line\n" if 2 <= $self->{_debug};
      if (defined($hit)) 
        {
        push(@{$self->{cache}}, $hit);
        };
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hits_found++;
      $hit->title($2);
      } 
    elsif ($state eq $HITS && m|Next\s\d+\smatches|)
      {
      print STDERR "next line\n" if 2 <= $self->{_debug};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      # Process the options.
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{_options}{'b'} = $self->{_next_to_retrieve};
      my($options) = '';
      foreach (keys %{$self->{_options}}) 
        {
        # printf STDERR "option: $_ is " . $self->{_options}{$_} . "\n" if $self->{_debug};
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Finally figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      $state = $TRAILER;
      } 
    else 
      {
      print STDERR "didn't match\n" if 2 <= $self->{_debug};
      };
    } # foreach
  if ($state ne $TRAILER) 
    {
    # Reached end of page without seeing "Next" button
    $self->{_next_url} = undef;
    } # if
  if (defined($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    } # if
  
  # sleep so as to not overload yahoo
  $self->user_agent_delay if (defined($self->{_next_url}));
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__

Yahoo categories & sites:

http://search.yahoo.com/search?p=star+wars&n=20

Yahoo Sites only:
http://search.yahoo.com/search?p=star+wars&n=20&h=s
http://search.yahoo.com/search?p=star+wars&n=20&h=s&b=21
