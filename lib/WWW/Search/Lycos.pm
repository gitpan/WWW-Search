# Lycos.pm
# by Wm. L. Scheding and Martin Thurn
# Copyright (C) 1996-1998 by USC/ISI
# $Id: Lycos.pm,v 1.8 1999/09/30 13:23:19 mthurn Exp $

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

WWW::Search::Lycos returns results only from www.lycos.com's "Web
Pages"; results from "Categories", "Web Sites", and "News & Media" are
ignored.
If you want to get results from www.lycos.com's categorized "Web
Sites", use Lycos::Sites instead.

The default search mode is "any" of the query terms.  If you want to
search for "ALL" of the query terms, add {'matchmode' => 'and'} as the
second argument to native_query().  More advanced query modes can be
added upon request; please contact the author.

www.lycos.com is pretty slow to respond; but I have not had a problem
with the default timeout.

www.lycos.com does not give the score, date, nor size of the pages at
the resulting URLs; therefore change_date(), score(), and size() will
never have a value.

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

Testing is done only on the children modules Lycos::Sites and
Lycos::Pages.

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

If it is not listed here, then it was not a meaningful nor released revision.

=head2 2.02, 1999-09-30

Now able to get Web Sites results via child module Sites.pm

=head2 2.01, 1999-07-13

=head2 1.04, 1999-04-30

Now uses lycos.com's advanced query format.

=head2 1.02, 1998-12-10

First public release after being adopted by Martin Thurn.

=cut

#####################################################################

package WWW::Search::Lycos;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

$VERSION = '2.02';
$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';

use Carp ();
use WWW::Search(qw( generic_option strip_tags ));
require WWW::SearchResult;

sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;
  # print STDERR " * this is Martin's new Lycos.pm!\n" if $self->{_debug};
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} = 0 if (!defined($self->{_debug}));

  # During Sites searches, lycos.com returns 10 hits per page no
  # matter what, so we don't depend on this value for our processing:
  my $DEFAULT_HITS_PER_PAGE = 100;
  $DEFAULT_HITS_PER_PAGE = 20 if 0 < $self->{_debug};
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  $self->{agent_e_mail} = 'MartinThurn@iname.com';
  $self->user_agent('non-robot');

  $self->{_next_to_retrieve} = 1;
  $self->{'_num_hits'} = 0;

  if (!defined($self->{_options})) 
    {
    $self->{'search_base_url'} = 'http://lycospro.lycos.com';
    $self->{_options} = {
                         'search_url' => $self->{'search_base_url'} .'/cgi-bin/pursuit',
                         'maxhits' => $self->{_hits_per_page},
                         'query' => $native_query,
                         'matchmode' => 'or',
                         'cat' => 'lycos',
                         'mtemp' => 'nojava',
                         'adv' => 1,
                        };
    } # if

  my $options_ref = $self->{_options};

  # Copy in options which were passed in our second argument:
  if (defined($native_options_ref)) 
    {
    foreach (keys %$native_options_ref) 
      {
      $options_ref->{$_} = $native_options_ref->{$_};
      } # foreach
    } # if

  # Copy in options which were set by a child object:
  if (defined($self->{'_child_options'})) 
    {
    foreach (keys %{$self->{'_child_options'}}) 
      {
      $self->{'_options'}->{$_} = $self->{'_child_options'}->{$_};
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
  # print STDERR " *   sending request (",$self->{_next_url},")\n";
  my($response) = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  if (!$response->is_success) 
    {
    return undef;
    }
  
  $self->{'_next_url'} = undef;
  print STDERR " *   got response\n" if $self->{_debug};
  # parse the output
  my ($HEADER, $HITS, $DESC, $COLLECT, $SKIP1, $SKIP2) = qw( HE HI DE CO K1 K2 );
  my $hits_found = 0;
  my $state = $HEADER;
  my $cite = "";
  my $hit;
  my $description = '';
  foreach ($self->split_lines($response->content()))
    {
    next if m@^$@; # short circuit for blank lines

    print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};

    # Note: if Lycos finds no Lycos-registered sites that match, it
    # automatically forward the query to Alta Vista.  If we see that
    # this has happened, we quit immediately.

    if ($state eq $HEADER && m|^Web\sSites</b></TD>|i)
      {
      # Actual line of input:
      # Web Sites</b></TD>
      $state = $SKIP2;
      }
    elsif ($state eq $SKIP1 && m|^<B>Featured On Lycos</B>$|)
      {
      $state = $SKIP2;
      }
    elsif ($state eq $SKIP2 && m|end vertical partner offers|)
      {
      #                        <!-- end vertical partner offers -->
      $state = $HITS;
      }
    elsif ($state eq $HEADER && m|<b>Web\sPages|i)
      {
      # Actual lines of input are:
      # <B>Web Pages</B>&nbsp;<I>(37054)</I>
      # <b>Web Pages
      print STDERR " page list intro\n" if ($self->{_debug});
      $self->approximate_result_count($1) if m=\((\d+)\)=;
      $state = $HITS;
      } # if

    elsif ($state eq $HITS && 
           (m@^(?:<LI>|\s)?<a href=\"?([^">]+?)\"?\>(.*?)</a>\s-\s(.*)$@i ||
            m@<LI><a href=\"?([^">]+?)\"?\>(.*?)</A>&nbsp;\<BR\>(.*)$@i))
      {
      # Actual line of input is:
      # <li><a href=http://www.cds.com/>CD Solutions Inc. CD-ROM, Replication, and Duplication page</a> - <font size=-1>CD Solutions makes CD-ROM production easy</font> 
      #  <a href="http://www.toysrgus.com">The <b>Star</b> <b>Wars</b> Collectors Archive</a> - <font size=-1>An archive of <b>Star</b> <b>Wars</b> Collectibles.</font> <font size=1>&nbsp;<br><br></font>
      # <a href="http://www.madal.com">Wholesale Only! Pokemon, Magic, <b>Star</b> <b>Wars</b>, <b>Star</b> Trek.  Sales to Qualified retail stores only!</a> - <font size=-1>Wholesale Sales to qualified retail outlets only. We are authorized distributors for Wizards of the Coast, Decipher and most other trading card game companies.  We have Pokemon.</font> <font size=1>&nbsp;<br><br></font>
      print STDERR "hit url+desc line\n" if 2 <= $self->{_debug};
      if (defined($hit)) 
        {
        push(@{$self->{cache}}, $hit);
        };
      $hit = new WWW::SearchResult;
      $hit->add_url($1);
      $hits_found++;
      $hit->title($2);
      $hit->description(strip_tags($3));
      }
    elsif ($state eq $HITS && m@<LI><A HREF=\"?([^">]+?)\"?>(.*)</A>@i)
      {
      # Actual line of input is:
      # <LI><A HREF="http://www.fortunecity.com/lavendar/python/134/">WISHBONE - A SHORT BIO OF THE GREAT SHOW FOR CHILDREN</A>&nbsp;<BR>
      # <p><b><a href="http://scifireplicas.com/movies/masks.htm">Merchandise Collector Masks - Star Wars</A></b>
      my ($url, $title) = ($1,$2);
      if ($url =~ m/dir\.lycos\.com/)
        {
        print STDERR "skip lycos category name\n" if 2 <= $self->{_debug};
        next;
        } # if
      print STDERR "hit url line\n" if 2 <= $self->{_debug};
      if (defined($hit)) 
        {
        push(@{$self->{cache}}, $hit);
        };
      $hit = new WWW::SearchResult;
      $hit->add_url($url);
      $hits_found++;
      $hit->title($title);
      if ($url =~ m=//news\.lycos\.com/=)
        {
        $state = $COLLECT;
        }
      else
        {
        $state = $DESC;        
        }
      }

    elsif ($state eq $COLLECT && m=^(.*?)<br>=i)
      {
      print STDERR "end of description collection\n" if 2 <= $self->{_debug};
      $description .= $1;
      $hit->description($description);
      $description = '';
      $state = $HITS;
      }
    elsif ($state eq $COLLECT)
      {
      print STDERR "description collection\n" if 2 <= $self->{_debug};
      $description .= "$_ ";
      }

    elsif ($state eq $DESC && m=^<BR>$=)
      {
      # Actual line of input is:
      # <BR>
      print STDERR "lone BR line\n" if 2 <= $self->{_debug};
      # Do not change state; try to get the description from the next line
      }
    elsif ($state eq $DESC && m=^<TR><TD>$=)
      {
      # Actual line of input is:
      # <TR><TD>
      print STDERR "lone TR TD line\n" if 2 <= $self->{_debug};
      # This item has no description.
      $state = $HITS;
      }
    elsif ($state eq $DESC && m=^(.+)<BR>=i)
      {
      # Actual line of input is:
      # Star Wars logo &nbsp; Merchandise Collector Masks - Star Wars &nbsp; Emperor Palpatine Greedo Yoda Emperor Palpatine Gre<BR>http://scifireplicas.com/movies/masks.htm
      print STDERR "description line\n" if 2 <= $self->{_debug};
      my $sDescription = $1;
      $hit->description($sDescription) if defined($hit);
      $state = $HITS;
      }

    elsif ($state eq $HITS && m|<A\sHREF=\"?([^">]+)\"?\><B>next</B>|i)
      {
      print STDERR "next line\n" if 2 <= $self->{_debug};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      my $sURL = $1;
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_next_to_retrieve'} = $1 if $sURL =~ m/first=(\d+)/;
      $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
      print STDERR " * next URL is ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
      # print STDERR " * next URL is ", $self->{'_next_url'}, "\n";
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

ADVENCED QUERY RESULTS:
http://lycospro.lycos.com/cgi-bin/pursuit?mtemp=nojava&etemp=error_nojava&rt=1&qs=gt%7Cdate&npl=matchmode%3Dand%26adv%3D1&query=replication&maxhits=40&cat=lycos&npl1=ignore%3Dfq&fq=&lang=&rtwm=45000&rtpy=2500&rttf=5000&rtfd=2500&rtpn=2500&rtor=2500

OTHER OPTIONS:

cat=lycos&mtemp=nojava   Show results from Web Pages index only
cat=dirw&mtemp=sites     Show results from Lycos categorized Web Sites only
cat=dirw&mtemp=news      Search in News articles and Media only
cat=dir                  Search for Lycos named Categories only
