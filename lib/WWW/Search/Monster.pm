#
# Monster.pm
# Author: Alexander Tkatchev
# e-mail: Alexander.Tkatchev@cern.ch
#
# WWW::Search back-end for Monster
# http://jobsearch.monster.com/jobsearch.asp
#

package WWW::Search::Monster;

=head1 NAME

WWW::Search::Monster - class for searching Monster

=head1 SYNOPSIS

 use WWW::Search;
 my $oSearch = new WWW::Search('Monster');
 my $sQuery = WWW::Search::escape_query("unix and (c++ or java)");
 $oSearch->native_query($sQuery,
 			{'st' => 'CA',
			 'tm' => '14d'});
 while (my $res = $oSearch->next_result()) {
     print $res->company . "\t" . $res->title . "\t" . $res->change_date
	 . "\t" . $res->location . "\t" . $res->url . "\n";
 }

=head1 DESCRIPTION

This class is a Monster specialization of WWW::Search.
It handles making and interpreting Monster searches at
F<http://www.monster.com>. Monster supports Boolean logic with "and"s
"or"s. See F<http://jobsearch.monster.com/jobsearch_tips.asp> for a full
description of the query language.

The returned WWW::SearchResult objects contain B<url>, B<title>, B<company>,
B<location> and B<change_date> fields.

=head1 OPTIONS 

The following search options can be activated by sending
a hash as the second argument to native_query().

=head2 Restrict by Date

The default is to return jobs posted in last 30 days.
An example below changes the default to 14 days:

=over 2

=item   {'tm' => '14d'}

=back

=head2 Restrict by Location

No restriction by default.

=over 2

=item   {'st' => $state}

Only jobs in state $state. To select multiple states separate them with
a "+", e.g. {'st' => 'NY+NJ+CT'}

=item   {'lid' => $location_id}

Only jobs in $location_id. To find out what $location_id you need please look
at the source of F<http://jobsearch.monster.com>. Note that $location_id does
B<not> mean the area telephone code.

=back

=head2 Restrict by Job Category

Use {'fn' => $cat_id}  to select one or more job categories you want.
For multiple selection use a '+' sign, e.g. {'fn' => '1+2'}.
Possible categories are:

=over 2

=item * 1	Accounting/Finance

=item * 2	Administrative/Clerical

=item * 12	Creative Arts/Media

=item * 3	Education/Training

=item * 4	Engineering/Architect/Design

=item * 5	Human Resources

=item * 6	Information Technology

=item * 45	Insurance

=item * 7	Legal/Law Enforcement/Security

=item * 47	Manufacturing/Production

=item * 8	Marketing/Advertising

=item * 9	Medical/Healthcare

=item * 11	Other

=item * 44	Retail

=item * 10	Sales/Sales Management

=item * 46	Science/Bio-Pharmaceutical

=item * 13	Travel/Hospitality/Restaurant

=back

=head1 AUTHOR

C<WWW::Search::HeadHunter> is written and maintained by Alexander Tkatchev
(Alexander.Tkatchev@cern.ch).

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

#####################################################################

require Exporter;
require WWW::SearchResult;
require HTML::TokeParser;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.01';

use Carp ();
use WWW::Search(generic_option);

sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;
  $self->{agent_e_mail} = 'alexander.tkatchev@cern.ch';

  $self->user_agent('non-robot');

  if (!defined($self->{_options})) {
      $self->{'search_base_url'} = 'http://jobsearch.monster.com';
      $self->{_options} = {
	  'search_url' => $self->{'search_base_url'} . '/jobsearch.asp',
	  'q' => $native_query
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
    $options_ref->{$_} =~ s/\+/\,/g if($_ eq 'st');
    $options_ref->{$_} =~ s/\+/\&$_=/g unless($_ eq 'q');
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  # Finally figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;;
  $self->{_debug} = $options_ref->{'search_debug'};
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  my $debug = $self->{'_debug'};
  print STDERR " *   Monster::native_retrieve_some()\n" if($debug);
  
  # fast exit if already done
  return undef if (!defined($self->{_next_url}));
  
  # get some
  print STDERR " *   sending request (",$self->{_next_url},")\n" if($debug);
  my($response) = $self->http_request('GET', $self->{_next_url});
  $self->{'_next_url'} = undef;
  if (!$response->is_success) {
      print STDERR $response->error_as_HTML;
      return undef;
  };
  
  print STDERR " *   got response\n" if($debug);


  if($response->content =~ m/No jobs matched the query/) {
      print STDERR "No jobs matched the query\n";
      return 0;
  }

  my ($token,$tag);
  my $content = $response->content();
  my $p = new HTML::TokeParser(\$content);
  $content =~ s|<b>||ig;
  $content =~ s|</b>||ig;
  $content =~ s/  / /ig;
  $content =~ m/Jobs (\d+) to (\d+) of (\d+)/;
  my $nrows = $2 - $1 + 1;
  if($content =~ m/Next page &gt;&gt;/) {
      my $options;
      my $nexturl;
      PROCESS_FORM: while(1) {
	  $tag = $p->get_tag("form");
	  $nexturl = $self->{'search_base_url'} . '/'. 
	      $tag->[1]{'action'} . '?';
	  while(1) {
	      $token = $p->get_token();
	      my $type = $token->[0];
	      $tag = $token->[1];
	      next PROCESS_FORM if($type eq 'E' && $tag eq 'form');
	      next if($tag ne 'input');
	      my $value = $token->[2]{'value'};
	      last PROCESS_FORM if ($value =~ m/Next page \>\>/);
	      next PROCESS_FORM if ($value =~ m/\<\< Previous page/);
	      my $name = $token->[2]{'name'};
	      my $escaped = WWW::Search::escape_query($value);
	      $nexturl .= "$name=$escaped" . '&' ;
	  }
      }
      print STDERR "Next url is $nexturl\n" if($debug);
      $self->{'_next_url'} = $nexturl;
  } else {
      print STDERR "No next button\n" if($debug);
  } 

  my($hits_found) = 0;
  my($hit) = ();

  $p = new HTML::TokeParser(\$content);
  while(1) {
      $tag = $p->get_tag("td");
      my $data = $p->get_trimmed_text("/td");
      last if($data eq 'Location' ||
	      $data eq 'Company' ||
	      $data eq 'Modified');
  }
  for(my $i = 0; $i< $nrows; $i++) {
      $tag = $p->get_tag("tr");
      $tag = $p->get_tag("td");
      my $date = $p->get_trimmed_text("/td");
      $tag = $p->get_tag("td");
      my $location = $p->get_trimmed_text("/td");
      $tag = $p->get_tag("a");
      my $url = $self->{'search_base_url'} . $tag->[1]{href};
      my $title = $p->get_trimmed_text("/a");
      $tag = $p->get_tag("td");
      my $company = $p->get_trimmed_text("/td");
      $hit = new WWW::SearchResult;
      $hit->url($url);
      $hit->company($company);
      $hit->change_date($date);
      $hit->title($title);
      $hit->location($location);
      push(@{$self->{cache}}, $hit);
      $hits_found++;
  }
#  return 0;
  return $hits_found;
} # native_retrieve_some

1;
