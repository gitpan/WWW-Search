# Lycos.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Lycos.pm,v 1.13 1998/12/10 18:20:53 johnh Exp $

=head1 NAME

WWW::Search::Lycos - class for searching Lycos 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Lycos');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    print $oResult->url, "\n";

=head1 DESCRIPTION

This class is a Lycos specialization of L<WWW::Search>.  It handles
making and interpreting Lycos-site searches F<http://www.Lycos.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 NOTES

The default search mode is "any" of the query terms.  If you want to
search for "ALL" of the query terms, add {'matchmode' => 'and'} as the
second argument to native_query().  More advanced query modes can be
added upon request; please contact the author.

www.lycos.com is pretty slow to respond; but I've not had a problem
with the default timeout.

www.lycos.com does not give the total number of results available;
therefore approximate_result_count() will never have a value.

www.lycos.com does not give the score, date, nor size of the pages at
the resulting URLs; therefore change_date(), score(), and size() will
never have a value.

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 

  Test cases (accurate as of 1998-12-10):

    $file = 'test/Lycos/zero_result';
    $query = 'Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Lycos/one_page_result';
    $query = '"Chri'.'stie Ab'.'bott"';
    test($mode, $TEST_RANGE, 2, 50);

    $file = 'test/Lycos/multi_page_result';
    $query = 'repli'.'cation';
    test($mode, $TEST_GREATER_THAN, 100);

=head1 AUTHOR

As of 1998-12-07, C<WWW::Search::Lycos> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::Lycos> was originally written by Martin Thurn,
based on C<WWW::Search::Yahoo> version 1.12 of 1998-10-22.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 1.02, 1998-12-10

First public release after being adopted by Martin Thurn.

=cut
#'

#####################################################################

package WWW::Search::Lycos;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.02';

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;

sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;
  # print STDERR " * this is Martin's new Lycos.pm!\n" if $self->{_debug};
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} = 0 if (!defined($self->{_debug}));

  # Why waste time sending so many queries?  Do a whole lot all at once!
  my $DEFAULT_HITS_PER_PAGE = 100;
  $DEFAULT_HITS_PER_PAGE = 10 if $self->{_debug};
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  $self->{agent_e_mail} = 'MartinThurn@iname.com';

  $self->user_agent('non-robot');

  $self->{_next_to_retrieve} = 1;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options})) 
    {
    $self->{'search_base_url'} = 'http://www.lycos.com';
    $self->{_options} = {
                         'search_url' => $self->{'search_base_url'} .'/cgi-bin/pursuit',
                         # 'first' => $self->{_next_to_retrieve},
                         'maxhits' => $self->{_hits_per_page},
                         'query' => $native_query,
                         'matchmode' => 'or',
                         'adv' => 1,
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
  print STDERR " *   Lycos::native_retrieve_some()\n" if $self->{_debug};
  
  # Fast exit if already done:
  return undef if (!defined($self->{_next_url}));
  
  # If this is not the first page of results, sleep so as to not
  # overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  
  # Get some:
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
  my ($HEADER, $HITS, $DESC) = qw(HE HI DE);
  my $hits_found = 0;
  my $state = $HEADER;
  my $cite = "";
  my $hit = ();
  foreach ($self->split_lines($response->content()))
    {
    next if m@^$@; # short circuit for blank lines

    print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};
    # Note: if Lycos finds no Lycos-registered sites that match, it
    # automatically forward the query to Alta Vista.  If we see that
    # this has happened, we quit immediately:
    if (m|Matching Web Pages|i)
      {
      # Actual line of input is:
      # <FONT SIZE="+1">Matching Web Pages</FONT>
      print STDERR " page list intro\n" if ($self->{_debug});
      $state = $HITS;
      } # if

    if ($state eq $HITS && m@<p><b><a href=\"([^"]+)\">(.*)</A>@i)
      {
      # Actual line of input is:
      # <p><b><a href="http://scifireplicas.com/movies/masks.htm">Merchandise Collector Masks - Star Wars</A></b>
      print STDERR "hit url line\n" if 2 <= $self->{_debug};
      if (defined($hit)) 
        {
        push(@{$self->{cache}}, $hit);
        };
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hits_found++;
      $hit->title($2);
      $state = $DESC;
      }

    elsif ($state eq $DESC && m=^<BR>$=)
      {
      # Actual line of input is:
      # <BR>
      print STDERR "lone BR line\n" if 2 <= $self->{_debug};
      # Don't change state; try to get the description from the next line
      }
    elsif ($state eq $DESC && m=^(.+)<BR>=)
      {
      # Actual line of input is:
      # Star Wars logo &nbsp; Merchandise Collector Masks - Star Wars &nbsp; Emperor Palpatine Greedo Yoda Emperor Palpatine Gre<BR>http://scifireplicas.com/movies/masks.htm
      print STDERR "description line\n" if 2 <= $self->{_debug};
      my $sDescription = $1;
      $hit->description($sDescription) if defined($hit);
      $state = $HITS;
      }

    elsif ($state eq $HITS && m|<A\sHREF=\"([^"]+)\">next\s+&gt;&gt;<|i)
      {
      print STDERR "next line\n" if 2 <= $self->{_debug};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      my $sURL = $1;
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/first=(\d+)/;
      $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
      print STDERR " * next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
      $state = $HITS;
      } 
    else 
      {
      print STDERR "didn't match\n" if 2 <= $self->{_debug};
      }
    } # foreach

  if (defined($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    } # if
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__
