# Yahoo.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Yahoo.pm,v 1.10 1998/11/07 01:26:10 johnh Exp $

=head1 NAME

WWW::Search::Yahoo - class for searching Yahoo 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Yahoo');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    print $oResult->url, "\n";

=head1 DESCRIPTION

This class is a Yahoo specialization of L<WWW::Search>.  It handles
making and interpreting Yahoo-site searches F<http://www.yahoo.com>.
Performs the search on "Yahoo sites", and ignores AltaVista results
that Yahoo might tell us about.

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

  Test cases (accurate as of 1998-10-22):

    $file = 'test/Yahoo/zero_result';
    $query = 'Bogus' . 'NoSuchWord';
    test($mode, $TEST_EXACTLY);

    $file = 'test/Yahoo/one_page_result';
    $query = 'LS'.'AM';
    test($mode, $TEST_RANGE, 2, 50);

    $file = 'test/Yahoo/multi_page_result';
    $query = 'repli'.'cation';
    test($mode, $TEST_GREATER_THAN, 100);

=head1 AUTHOR

As of 1998-02-02, C<WWW::Search::Yahoo> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::Yahoo> was originally written by Wm. L. Scheding,
based on C<WWW::Search::AltaVista>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 1.12, 1998-10-22

BUG FIX: now captures citation descriptions;
BUG FIX: next page of results was often wrong or missing!

=head2 1.11, 1998-10-09

Now uses split_lines function

=head2 1.5

Fixed bug where next page tag was always missed.
Fixed the maximum_to_retrieve off-by-one problem.
Updated test cases.

=cut

#####################################################################

package WWW::Search::Yahoo;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

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

  # If we run as a robot, WWW::RobotRules fetches the
  # http://www.yahoo.com instead of http://www.yahoo.com/robots.txt,
  # and dumps a thousand warnings to STDERR.
  $self->user_agent('non-robot');

  $self->{_next_to_retrieve} = 0;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options})) 
    {
    $self->{'search_base_url'} = 'http://search.yahoo.com';
    $self->{_options} = {
                         'search_url' => $self->{'search_base_url'} .'/search',
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
  foreach (sort keys %$options_ref) 
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
  print STDERR " * pages to request: $iNumPages pages of ", $self->{'_hits_per_page'}, " hits each.\n" if $self->{_debug};
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  print STDERR " *   Yahoo::native_retrieve_some()\n" if $self->{_debug};
  
  # fast exit if already done
  return undef if (!defined($self->{_next_url}));
  
  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  
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
  foreach ($self->split_lines($response->content()))
    {
    next if m@^$@; # short circuit for blank lines
    print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};
    # Note: if Yahoo finds no Yahoo-registered sites that match, it
    # automatically forward the query to Alta Vista.  If we see that
    # this has happened, we quit immediately:
    if (m|<center><p><font size="+1"><b>Alta Vista Web Pages</b></font>|i)
      {
      # Actual line of input is:
      # <center><p><font size="+1"><b>Alta Vista Web Pages</b></font>
      print STDERR "alta vista page list intro\n";
      last;
      } # if
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
    elsif ($state eq $HITS && m=^(.*?)<BR><cite>=)
      {
      # Actual line of input is:
      # 
      print STDERR "citation line\n" if 2 <= $self->{_debug};
      if (ref($hit))
        {
        my $sDescrip = '';
        if (defined($hit->description) and $hit->description ne '')
          {
          $sDescrip = $hit->description . ' ';
          }
        $sDescrip .= $1;
        $hit->description($sDescrip);
        $state = $HITS;
        } # if hit
      } # CITATION line
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
    elsif ($state eq $HITS && m|<a\shref=\"([^"]+)\">Next\s\d+\s(Site\s)?Matches|i)
      {
      print STDERR "next line\n" if 2 <= $self->{_debug};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      my $sURL = $1;
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/b=(\d+)/;
      $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
      print STDERR " * next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
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
  
  return $hits_found;
  } # native_retrieve_some

1;

__END__

Yahoo categories & sites:

http://search.yahoo.com/search?p=star+wars&n=20

Yahoo Sites only:
http://search.yahoo.com/search?p=star+wars&n=20&h=s
http://search.yahoo.com/search?p=star+wars&n=20&h=s&b=21
