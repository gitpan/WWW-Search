###############################################################
# ExciteNews.pm                                               
# by Jim Smyser                                               
# Copyright (c) 1999 by Jim Smyser & USC/ISI                  
# $Id: News.pm,v 1.2 1999/06/30 20:12:06 mthurn Exp $
# Complete copyright notice follows below.                    
###############################################################

=head1 NAME

WWW::Search::Excite::News - class for searching ExciteNews

=head1 SYNOPSIS

require WWW::Search;
$search = new WWW::Search('Excite::News');

=head1 DESCRIPTION

Class for searching Excite News F<http://www.excite.com>.
Excite has one of the best news bot on the web.

If you use the raw method for this backend you will need to include
a "<p>" at end of your print statement, example:
     print $result->raw(), "<p>\n";

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
set of results, otherwise it sets it to undef to indicate we are done.

=head1 AUTHOR

Maintained by Jim Smyser <jsmyser@bigfoot.com>

=head1 TESTING

NONE AVAILABLE FOR THIS BACKEND!

=head1 COPYRIGHT

The original parts from John Heidemann are subject to
following copyright notice:
         
Copyright (c) 1996-1998 University of Southern California.
All rights reserved.
                                                                        
THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

#####################################################################

package WWW::Search::Excite::News;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.01';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

# private
sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;
  
  # Set some private variables:
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} ||= 0;
  $self->{'_hits_per_page'} = '50';
  $self->{agent_e_mail} = 'jsmyser@bigfoot.com.com';
  $self->user_agent(0);
  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;
  if (!defined($self->{_options})) {
    $self->{_options} = {
                         'search_url' => 'http://search.excite.com/search.gw',
                         'c' => 'timely&showSummary=true',
                         'search' => $native_query,
                         'perPage' => $self->{'_hits_per_page'},
                         'start' => $self->{'_next_to_retrieve'},
                        };
    }
  my $options_ref = $self->{_options};
  if (defined($native_options_ref))
    {
    # Copy in new options.
    foreach (keys %$native_options_ref)
      {
      $options_ref->{$_} = $native_options_ref->{$_};
      } 
    } 
  # Process the options.
  my $options = '';
  foreach (keys %$options_ref)
    {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  # Yikes, gotta chop the trailing & 
  chop $options;
  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
  } 
  
sub begin_new_hit
  {
  my($self) = shift;
  my($old_hit) = shift;
  my($old_raw) = shift;
  # Save it
  if (defined($old_hit)) {
    $old_hit->raw($old_raw) if (defined($old_raw));
    push(@{$self->{cache}}, $old_hit);
    }
  # Make a new hit.
  return (new WWW::SearchResult, '');
  }

# private
sub native_retrieve_some
  {
  my ($self) = @_;
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  # Sleep so as to not overload the server for next page(s)
  print STDERR "***Sending request (",$self->{_next_url},")\n" if $self->{'_debug'};
  my $response = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  unless ($response->is_success)
    {
    return undef;
    }
  print STDERR "***Picked up a response..\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($HEADER, $HITS, $SOURCE, $DESC, $DATE, $TRAILER) = qw(HE HH SO DE DA TR);
  my ($raw) = '';
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
  foreach ($self->split_lines($response->content()))
    {
    next if m/^$/;              # short circuit for blank lines
    print STDERR " *** $state ===$_===" if 2 <= $self->{'_debug'};
    
    if ($state eq $HEADER && m=^\[(\d+)\s+hits.=i) {
      print STDERR "**Result Count**\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } elsif ($state eq $HEADER && m@&nbsp;(\d+)-(\d+)@i) {
        print STDERR "**Next Page Header**\n" if 2 <= $self->{'_debug'};
        $state = $HITS;
        
        } elsif ($state eq $HITS && m@.*?<A HREF=.*?;([^"]+)\">(.*)</A></b>&nbsp;@i) {
          print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
          ($hit, $raw) = $self->begin_new_hit($hit, $raw);
          $raw .= $_;
          $self->{'_num_hits'}++;
          $hits_found++;
          $hit->add_url($1);
          $hit->title($2);
          $state = $SOURCE;
          } elsif ($state eq $SOURCE && m@(\((.*))@i) {
            print STDERR "**News Source**\n" if 2 <= $self->{'_debug'};
            $raw .= $_;
            $hit->score($1);
            $state = $DESC;
            } elsif ($state eq $DESC && m@<BR>(.*)$@i) {
              print STDERR "**Found Description**\n" if 2 <= $self->{'_debug'};
              $raw .= $_;
              $hit->description($1);
              $state = $DATE;
              
              } elsif ($state eq $DATE && m@<BR>(<i>(.*))&nbsp;@) {
                print STDERR "**Got the Date**\n" if 2 <= $self->{'_debug'};
                $raw .= $_;
                $hit->index_date($1);
                $state = $HITS;
                
                } elsif ($state eq $HITS && m/<INPUT\s[^>]*VALUE=\"Next\sResults\"/i) {
                  print STDERR "**Going to Next Page**\n" if 2 <= $self->{'_debug'};
                  $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
                  $self->{'_options'}{'start'} = $self->{'_next_to_retrieve'};
                  my($options) = '';
                  foreach (keys %{$self->{_options}})
                    {
                    next if (generic_option($_));
                    $options .= $_ . '=' . $self->{_options}{$_} . '&';
                    }
                  chop $options;
                  # Finally, figure out the url.
                  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
                  $state = $TRAILER;
                  } else {
                    print STDERR "**Nothing Matched**\n" if 2 <= $self->{'_debug'};
                    }
    } 
  if ($state ne $TRAILER)
    {
    # no other pages missed
    $self->{_next_url} = undef;
    }
  return $hits_found;
  } # native_retrieve_some
      
1;
      
