# WebCrawler.pm
# Copyright (C) 1998 by Martin Thurn
# $Id: WebCrawler.pm,v 1.14 1999/06/30 15:41:29 mthurn Exp $

=head1 NAME

WWW::Search::WebCrawler - class for searching WebCrawler 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('WebCrawler');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    print $oResult->url, "\n";

=head1 DESCRIPTION

This class is a WebCrawler specialization of WWW::Search.
It handles making and interpreting WebCrawler searches
F<http://www.WebCrawler.com>.

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

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 
See $TEST_CASES below.

=head1 AUTHOR

As of 1998-03-16, C<WWW::Search::WebCrawler> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::WebCrawler> was originally written by Martin Thurn
based on C<WWW::Search::HotBot>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

If it's not listed here, then it wasn't a meaningful or released version.

=head2 1.13, 1999-03-29

Remove extraneous HTML from description (thanks to Jim Smyser jsmyser@bigfoot.com)

=head2 1.11, 1998-10-09

Now uses split_lines function

=head2 1.9

1998-08-20: New format of www.webcrawler.com output.

=head2 1.7

\n changed to \012 for MacPerl compatibility

=head2 1.5

1998-05-29: New format of www.webcrawler.com output.

=head2 1.3

First publicly-released version.

=cut

#####################################################################

package WWW::Search::WebCrawler;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.14';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('WebCrawler', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_BY_COUNTING, 0);
&test('WebCrawler', '$MAINTAINER', 'one_page', 'dise'.'stablishmentarianism', \$TEST_RANGE, 2,99);
&test('WebCrawler', '$MAINTAINER', 'two_page', 'Lan'.'do', \$TEST_GREATER_THAN, 50);
ENDTESTCASES

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;


# public
sub version { $VERSION }

# private
sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;

  # Set some private variables:
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} ||= 0;

  my $DEFAULT_HITS_PER_PAGE = 100;
  $DEFAULT_HITS_PER_PAGE = 10 if $self->{_debug};
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  # Add one to the number of hits needed, because Search.pm does ">"
  # instead of ">=" on line 672!
  my $iMaximum = 1 + $self->maximum_to_retrieve;
  # Divide the problem into N pages of K hits per page.
  my $iNumPages = 1 + int($iMaximum / $self->{'_hits_per_page'});
  if (1 < $iNumPages)
    {
    $self->{'_hits_per_page'} = 1 + int($iMaximum / $iNumPages);
    }
  else
    {
    $self->{'_hits_per_page'} = $iMaximum;
    }
  $self->{agent_e_mail} = 'MartinThurn@iname.com';

  # As of 1998-03-16, WebCrawler apparently doesn't like WWW::Search!  Response was
  # 403 (Forbidden) Forbidden by robots.txt
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
  if (!defined($self->{_options})) 
    {
    $self->{_options} = {
                         'search_url' => 'http://www.webcrawler.com/cgi-bin/WebQuery',
                         'search' => $native_query,
                         'start' => $self->{'_next_to_retrieve'},
                         'showSummary' => 'true',
                         'perPage' => $self->{'_hits_per_page'},
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
  my $options = '';
  foreach (keys %$options_ref) 
    {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  # Delete the last '&' (WebCrawler chokes if it is there!) :
  chop $options;

  # Finally figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
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
  my $response = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  unless ($response->is_success) { return undef }

  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($HEADER, $COUNT, $HITS, $NBSP, $URL, $DESC, $TRAILER) = qw(HE CT HH NB UR DE TR);
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
  foreach ($self->split_lines($response->content())) 
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " * $state ===$_===" if 2 <= $self->{'_debug'};
    if ($state eq $COUNT && 
        m=^Result$=i) 
      {
      # Actual line of input is:
      # Result
      $self->approximate_result_count(1);
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $state = $HITS;
      }
    elsif ($state eq $HEADER && 
        m=Web\sResults\sfor:=i) 
      {
      # Actual line of input is:
      # <P><FONT SIZE=3><B>Web Results for:</B></FONT>&nbsp;&nbsp;
      print STDERR "header line\n" if 2 <= $self->{'_debug'};
      $state = $COUNT;
      }
    elsif ($state eq $COUNT && 
           m=\([-0-9]+\s+of\s+(\d+)\)=i) 
      {
      # Actual line of input is:
      # (10 of 85)
      print STDERR "count line\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HITS && 
           m=^<DT>.+?(\d+)\%=)
      {
      print STDERR "hit percent line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <DT><FONT FACE="Times" COLOR="#006699"><B>64% </B></FONT>
      if (defined($hit))
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $self->{'_num_hits'}++;
      $hits_found++;
      $hit->score($1);
      $state = $NBSP;
      }
    elsif ($state eq $NBSP && 
           m=^&nbsp;&nbsp;$=)
      {
      print STDERR "hit double nbsp line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # &nbsp;&nbsp;
      $state = $URL;
      }
    elsif ($state eq $URL && 
           m|<A\s+HREF=\"?([^\">]+)\"?>([^<]+)|i)
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <A HREF="http://www.geocities.com/Area51/Chamber/4729/">BACK TO THE FUTURE COLLECTIBLES</A>
      # Sometimes there are no quotes around the URL!
      # Sometimes the </A> is on the next line.
      # Sometimes there is a /r right before the </A>
      $hit->add_url($1);
      $hit->title($2);
      $state = $DESC;
      }
    elsif ($state eq $DESC &&
           m|^<DD>(.*?)<NOBR>|)
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      $hit->description($1);
      $state = $HITS;
      } # line is description

    elsif ($state eq $HITS && m/^<INPUT\s(TYPE=\"submit\"\s)?VALUE=\"Get\sthe\s(next|last)\s/i)
      {
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      # Process the options.
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_options'}{'start'} = $self->{'_next_to_retrieve'};
      my($options) = '';
      foreach (keys %{$self->{_options}}) 
        {
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Delete the last '&' (WebCrawler chokes if it is there!) :
      chop $options;
      # Finally, figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
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

__END__

Martin''s page download results, 1998-02:

simplest arbitrary page:

http://www.webcrawler.com/cgi-bin/WebQuery?search=star+wars+collecting;showSummary=true;perPage=25;start=0

Here''s what I''m generating:

http://www.webcrawler.com/cgi-bin/WebQuery?search=LSAM;perPage=24;start=0;showSummary=true;
http://www.webcrawler.com/cgi-bin/WebQuery?search=LSAM;perPage=30;start=0;showSummary=true;
