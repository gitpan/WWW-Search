#
# Dice.pm
# Author: Alexander Tkatchev 
# e-mail: Alexander.Tkatchev@cern.ch
#
# WWW::Search back-end Dice
# http://jobsearch.dice.com/jobsearch/jobsearch.cgi
#

package WWW::Search::Dice;

=head1 NAME

WWW::Search::Dice - class for searching Dice

=head1 SYNOPSIS

 use WWW::Search;
 my $oSearch = new WWW::Search('Dice');
 my $sQuery = WWW::Search::escape_query("unix and (c++ or java)");
 $oSearch->native_query($sQuery,
 			{'method' => 'bool',
		         'state' => 'CA',
		         'daysback' => 14});
 while (my $res = $oSearch->next_result()) {
     if(isHitGood($res->url)) {
 	 my ($company,$title,$date,$location) = 
	     $oSearch->getMoreInfo($res->url);
 	 print "$company $title $date $location " . $res->url . "\n";
     } 
 }

 sub isHitGood {return 1;}

=head1 DESCRIPTION

This class is a Dice specialization of WWW::Search.
It handles making and interpreting Dice searches at
F<http://www.dice.com>.


By default, returned WWW::SearchResult objects contain only url, title
and description which is a mixture of location and skills wanted.
Function B<getMoreInfo( $url )> provides more specific info - it has to
be used as

    my ($company,$title,$date,$location) = 
        $oSearch->getMoreInfo($res->url);

=head1 OPTIONS 

The following search options can be activated by sending
a hash as the second argument to native_query().

=head2 Format / Treatment of Query Terms

The default is to treat entire query as a boolean
expression with AND, OR, NOT and parentheses

=over 2

=item   {'method' => 'and'}

Logical AND of all the query terms.

=item   {'method' => 'or'}

Logical OR of all the query terms.

=item   {'method' => 'bool'}

treat entire query as a boolean expression with 
AND, OR, NOT and parentheses.
This is the default option.

=back

=head2 Restrict by Date

The default is to return jobs posted in last 30 days

=over 2

=item   {'daysback' => $number}

Display jobs posted in last $number days

=back

=head2 Restrict by Location

The default is "ALL" which means all US states

=over 2

=item   {'state' => $state} - Only jobs in state $state.

=item   {'state' => 'CDA'} - Only jobs in Canada.

=item   {'state' => 'INT'} - To select international jobs.

=item   {'state' => 'TRV'} - Require travel.

=item   {'state' => 'TEL'} - Display telecommute jobs.

=back

Multiple selections are possible. To do so, add a "+" sign between
desired states, e.g. {'state' => 'NY+NJ+CT'}

You can also restrict by 3-digit area codes. The following option does that:

=over 2

=item   {'acode' => $area_code}

=back

Multiple area codes (up to 5) are supported.

=head2 Restrict by Job Term

No restrictions by default.

=over 2

=item {'term' => 'CON'} - contract jobs

=item {'term' => 'C/H'} - contract to hire

=item {'term' => 'FTE'} - full time

=back

Use a '+' sign for multiple selection.

There is also a switch to select either W2 or Independent:

=over 2

=item {'addterm' => 'W2ONLY'} - W2 only

=item {'addterm' => 'INDOK'} - Independent ok

=back

=head2 Restrict by Job Type

No restriction by default. To select jobs with specific job type use the
following option:

=over 2

=item   {'jtype' => $jobtype}

=back

Here $jobtype (according to F<http://www.dice.com>) can be one or more 
of the following:

=over 2

=item * ANL - Business Analyst/Modeler

=item * COM - Communications Specialist

=item * DBA - Data Base Administrator

=item * ENG - Other types of Engineers

=item * FIN - Finance / Accounting

=item * GRA - Graphics/CAD/CAM

=item * HWE - Hardware Engineer

=item * INS - Instructor/Trainer

=item * LAN - LAN/Network Administrator

=item * MGR - Manager/Project leader

=item * OPR - Data Processing Operator

=item * PA - Application Programmer/Analyst

=item * QA - Quality Assurance/Tester

=item * REC - Recruiter

=item * SLS - Sales/Marketing

=item * SWE - Software Engineer

=item * SYA - Systems Administrator

=item * SYS - Systems Programmer/Support

=item * TEC - Custom/Tech Support

=item * TWR - Technical Writer

=item * WEB - Web Developer / Webmaster

=back

=head2 Limit total number of hits

The default is to stop searching after 500 hits.

=over 2

=item  {'num_to_retrieve' => $num_to_retrieve}

Changes the default to $num_to_retrieve.

=back

=head1 AUTHOR

C<WWW::Search::Dice> is written and maintained by Alexander Tkatchev
(Alexander.Tkatchev@cern.ch).

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

require Exporter;
require WWW::SearchResult;
require HTML::TokeParser;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.00';

use Carp ();
use WWW::Search(generic_option);

sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;
  $self->{agent_e_mail} = 'alexander.tkatchev@cern.ch';

  $self->user_agent('non-robot');

  $self->{_first_call} = 1;

  if (!defined($self->{_options})) {
      $self->{_options} = {
	  'search_url' => 'http://jobsearch.dice.com/jobsearch/jobsearch.cgi',
	  'banner' => 0,
	  'brief' => 'true',
	  'method' => 'bool',
	  'query' => $native_query,
	  'state' => 'ALL',
	  'jtype' => 'all',
	  'daysback' => 30,
	  'num_per_page' => 50,
	  'num_to_retrieve' => 500
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
    # convert things like 'state' => 'NY+NJ' into 'state' => 'NY&state=NJ'
    $options_ref->{$_} =~ s/\+/\&$_=/g unless($_ eq 'query');
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
  $self->{_to_post} = $options;
  # Finally figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'};

  $self->{_debug} = $options_ref->{'search_debug'};
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  my $debug = $self->{'_debug'};
  print STDERR " *   Dice::native_retrieve_some()\n" if ($debug);
  
  # fast exit if already done
  return undef if (!defined($self->{_next_url}));
  
  my ($response,$tag,$url);
  if($self->{_first_call}) {
      $self->{_first_call} = 0;
      print STDERR "Sending POST request to " . $self->{_next_url} .
	  "\tPOST options: " . $self->{_to_post} . "\n" 
	      if ($debug);
      my $req = new HTTP::Request('POST', $self->{_next_url});
      $req->content_type('application/x-www-form-urlencoded');
      $req->content($self->{_to_post});
      my $ua = $self->{user_agent};
      $response = $ua->request($req);
      if($response->content() =~ 
	 m/Sorry, no documents matched your search criteria/) {
	  print STDERR "Sorry, no hits found\n"; 
	  $self->{'_next_url'} = $undef;
	  return 0;
      }
      my $p = new HTML::TokeParser(\$response->content());
      $tag = $p->get_tag("a");
      $url = $tag->[1]{href};
      $url =~ s/\;/\&/g;
      $self->{'_next_url'} = $url;
      print STDERR "Next url is " . $self->{'_next_url'} . "\n" if ($debug);
      return 0;
  }


  print STDERR " *   sending request (",$self->{_next_url},")\n" 
      if($debug);
  $response = $self->http_request('GET', $self->{_next_url});  
  print STDERR " *   got response\n" if($debug);
  $self->{'_next_url'} = undef;
  if (!$response->is_success) {
      print STDERR $response->error_as_HTML;
      return undef;
  }
  
  my $p = new HTML::TokeParser(\$response->content());
  while(1) {
      $tag = $p->get_tag("a");
      $url = $tag->[1]{href};
      last if($url =~ m/DandL/);
  }

  my($hits_found) = 0;
  my($hit) = ();
  while(1) {
      $p->get_tag("/a");
      my $title = $p->get_trimmed_text("/dt");
      $title =~ s/ - //;
      $title =~ s/\s+//;
      my $description = $p->get_trimmed_text("/font");
#      print STDERR "$url\t|$title\t|$description\n" if($debug);
      $hit = new WWW::SearchResult;
      $hit->url($url);
      $hit->title($title);
      $hit->description($description);
      push(@{$self->{cache}}, $hit);
      $hits_found++;

      $tag = $p->get_tag("a");
      $url = $tag->[1]{href};
      last unless($url =~ m/DandL/);
  }

  if($response->content() =~ m/Show next/) {
      while(1) {
	  my $linktitle = $p->get_trimmed_text("/a");
	  if($linktitle =~ m/Show next/) {
	      $self->{'_next_url'} = $url;
	      print STDERR "Next url is $url\n" if($debug);
	      last;
	  }
	  $tag = $p->get_tag("a");
	  $url = $tag->[1]{href};
      }
  } else {
      print STDERR "**************** No next link \n" if($debug);
  }

  return $hits_found;
} # native_retrieve_some

sub getMoreInfo {
    my $self = shift;
    my $url = shift;
    my ($company,$title,$date,$location) = ("some company","somebody",
					    "/mm/dd/yy","USA");
    my($response) = $self->http_request('GET',$url);
    if ($response->is_success) {
	my $p = new HTML::TokeParser(\$response->content());
	my $tag = $p->get_tag("img");
	$company = $tag->[1]{'alt'};
	# sometimes there is no company image 
        # at the beginning of HTML page...
	$p = new HTML::TokeParser(\$response->content());
	while(1) {
	    my $tag = $p->get_tag("td");
	    my $str = $p->get_trimmed_text("/td");
	    if($str =~ m/Title:/) {
		$tag = $p->get_tag("td");
		$title = $p->get_trimmed_text("/td");
	    } elsif($str =~ m/Date Posted:/) {
		$tag = $p->get_tag("td");
		$date = $p->get_trimmed_text("/td");
	    } elsif($str =~ m/Location:/) {
		$tag = $p->get_tag("td");
		$location = $p->get_trimmed_text("/td");
		last;
	    }
	}
    }
    return ($company,$title,$date,$location);
}

1;
