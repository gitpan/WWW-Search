# AltaVista/Intranet.pm
# by Martin Thurn
# $Id: Intranet.pm,v 1.4 1999/07/13 17:50:59 mthurn Exp $
#
# Complete copyright notice follows below.

=head1 NAME

WWW::Search::AltaVista::Intranet - class for searching via AltaVista Search Intranet 2.3

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('AltaVista::Intranet', 
                                (_host => 'copper', _port => 9000),);
  my $sQuery = WWW::Search::escape_query("+investment +club");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class implements a search on AltaVista's Intranet Search.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 TESTING

There is no standard built-in test mechanism for this module, because
very few users of WWW::Search will have AltaVista installed on their
intranet.  (How's that for an excuse? ;-)

=head1 AUTHOR

C<WWW::Search::AltaVista::Intranet> 
was written by Martin Thurn <MartinThurn@iname.com>

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

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 1.03, 1999-06-20

First publicly-released version.

=cut

#####################################################################

package WWW::Search::AltaVista::Intranet;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::AltaVista Exporter);
$VERSION = '2.01';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&no_test('AltaVista::Intranet', '$MAINTAINER');
ENDTESTCASES

use WWW::Search::AltaVista;
use Carp;

# private
sub native_setup_search
  {
  my ($self, $sQuery, $rhOptions) = @_;
  my $sMsg = '';
  unless (defined($self->{_host}) && ($self->{_host} ne ''))
    { $sMsg .= " --- _host not specified in WWW::Search::AltaVista::Intranet object\n"; }
  unless (defined($self->{_port}) && ($self->{_port} ne ''))
    { $sMsg .= " --- _port not specified in WWW::Search::AltaVista::Intranet object\n"; }
  if ($sMsg ne '')
    {
    carp $sMsg;
    return undef;
    } # if
  $$rhOptions{'search_url'} = 'http://'. $self->{_host} .':'. $self->{_port} .'/cgi-bin/query';
  $$rhOptions{'text'} = '';
  $$rhOptions{'mss'} = 'simple';
  # let AltaVista.pm finish up the hard work.
  return $self->SUPER::native_setup_search($sQuery, $rhOptions);
  }


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  print STDERR " *   AltaVista::Intranet::native_retrieve_some()\n" if $self->{_debug};
  
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
    }
  
  $self->{'_next_url'} = undef;
  print STDERR " *   got response\n" if $self->{_debug};
  # parse the output
  my ($HEADER, $HITS, $TITLE,$DESC,$DATE,$SIZE,$TRAILER) = qw(HE HI TI DE DA SI TR);
  my $hits_found = 0;
  my $state = ($HEADER);
  my $cite = "";
  my $hit = ();
  foreach ($self->split_lines($response->content()))
    {
    next if m@^$@; # short circuit for blank lines
    print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};
    if ($state eq $HEADER && m:AltaVista\sfound\s(\d+):i)
      {
      # Actual line of input is:
      # <b><b><!-- avecho val="About " if="notexists $avs.header.isExact" -->AltaVista found 33 Web pages for you. </b></b>
      print STDERR "count line\n" if 2 <= $self->{_debug};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # COUNT line
    elsif ($state eq $HITS && m:\<dl>\<dt>\<b>(\d+)\.:i)
      {
      # Actual line of input is:
      # <dl><dt><b>1.   </b>
      print STDERR "rank line\n" if 2 <= $self->{_debug};
      $state = $TITLE;
      }
    elsif ($state eq $TITLE && m:\<a\shref=\"([^"]+)\">:i)
      {
      # Actual line of input is:
      # <!-- PAV 1 --><a href="http://www.tasc.com/news/prism/9811/51198.html"><!-- PAV end --><b>Arlington Pond Waterski Club 11/98                                                  </b></a><dd>
      print STDERR "title line\n" if 2 <= $self->{_debug};
      if (ref($hit)) 
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hits_found++;
      if (m:\<b>(.+?)\</b>:i)
        {
        my $sTitle = $1;
        $sTitle =~ s/\s+$//;
        $hit->title($sTitle);
        } # if
      $state = $DESC;
      } # TITLE line
    elsif ($state eq $DESC)
      {
      # Actual line of input is:
      # The Analytic Investment Club. TASC employees in Northern Virginia formed The Analytic Investment Club (TAIC) in June 1995. The goals of the club are to...<br>
      print STDERR "description line\n" if 2 <= $self->{_debug};
      $hit->description($_);
      $state = $DATE;
      } # DESCRIPTION line
    elsif ($state eq $DATE && m:Last modified (.+)$:i)
      {
      # Actual line of input is:
      # Last modified 15-Jan-1999
      print STDERR "date line\n" if 2 <= $self->{_debug};
      $hit->change_date($1);
      $state = $SIZE;
      } # DATE line
    elsif ($state eq $SIZE && m:page size (\S+):i)
      {
      # Actual line of input is:
      # - page size 5K
      print STDERR "size line\n" if 2 <= $self->{_debug};
      my $iSize = $1;
      $iSize *= 1024 if ($iSize =~ s@k$@@i);
      $iSize *= 1024*1024 if ($iSize =~ s@M$@@i);
      $hit->size($iSize);
      $state = $HITS;
      } # SIZE line
    elsif ($state eq $HITS && m:next\s*&gt;&gt;:i)
      {
      # Actual line of input is:
      # <a href="cgi-bin/query?mss=simple&what=web&pg=q&q=investment+club&text=yes&kl=XX&enc=iso88591&filter=intranet&stq=10">[<b>next &gt;&gt;</b>]</a>
      print STDERR "next link line\n" if 2 <= $self->{_debug};
      if (m:href=\"([^\"]+)\":i)
        {
        my $relative_url = $1;
        $self->{_next_url} = new URI::URL($relative_url, $self->{_base_url});
        } # if
      $state = $TRAILER;
      } # NEXT line
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

Here is a complete URL:

http://copper.dulles.tasc.com:9000/cgi-bin/query?mss=simple&pg=q&what=web&user=searchintranet&text=yes&enc=iso88591&filter=intranet&kl=XX&q=forensics&act=Search

This is the barest-bones version that still works:

http://copper.dulles.tasc.com:9000/cgi-bin/query?pg=q&fmt=d&q=forensics&text=yes
