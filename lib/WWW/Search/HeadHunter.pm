#
# HeadHunter.pm
# Author: Alexander Tkatchev
# e-mail: Alexander.Tkatchev@cern.ch
#
# WWW::Search back-end for HeadHunter
# http://www.Headhunter.net/scripts/jobquery.asp
#

package WWW::Search::HeadHunter;

=head1 NAME

WWW::Search::HeadHunter - class for searching HeadHunter

=head1 SYNOPSIS

 use WWW::Search;
 my $oSearch = new WWW::Search('HeadHunter');
 my $sQuery = WWW::Search::escape_query("unix and (c++ or java)");
 $oSearch->native_query($sQuery,
 			{'SID' => 'CA',
		         'Freshness' => 14});
 while (my $res = $oSearch->next_result()) {
     print $res->company . "\t" . $res->title . "\t" . $res->change_date
	 . "\t" . $res->location . "\t" . $res->url . "\n";
 }

=head1 DESCRIPTION

This class is a HeadHunter specialization of WWW::Search.
It handles making and interpreting HeadHunter searches at
F<http://www.HeadHunter.net>. HeadHunter supports Boolean logic with "and"s
"or"s. See F<http://www.HeadHunter.net/Help/jobquerylang.htm> for a full
description of the query language.

The returned WWW::SearchResult objects contain B<url>, B<title>, B<company>,
B<location> and B<change_date> fields.

=head1 OPTIONS 

The following search options can be activated by sending
a hash as the second argument to native_query().

=head2 Restrict by Date

The default is to return jobs posted in last 30 days (internally done by 
HeadHunter search engine).

=over 2

=item   {'Freshness' => $number}

Display jobs posted in last $number days

=back

=head2 Restrict by Location

No restriction by default.

=over 2

=item   {'Town' => $town}

To select jobs from approximately 30 miles around the city.

=item   {'SID' => $loc}

Only jobs in state/province $loc (two letters only).

=item   {'CID' => 'US'}

To view only US jobs. To see jobs from other countries, check out
the acceptable country list at F<http://www.Headhunter.net/listcoun.htm>.

=back

=head2 Restrict by Salary

No restrictions by default.

=over 2

=item {'Pay' => 'P1'} - less than $15,000 Per Year

=item {'Pay' => 'P2'} - $15,000 - $30,000 Per Year

=item {'Pay' => 'P3'} - $30,000 - $50,000 Per Year

=item {'Pay' => 'P4'} - $50,000 - $75,000 Per Year

=item {'Pay' => 'P4'} - $75,000 - $100,000 Per Year

=item {'Pay' => 'P6'} - more than $100,000 Per Year

=back

To select several pay ranges use a '+' sign, e.g. {'Pay' => 'P3+P4'}

=head2 Restrict by Employment Type

No restrictions by default.

=over 2

=item {'EmpType' => 'Typ1'} - Employee

=item {'EmpType' => 'Typ2'} - Contract

=item {'EmpType' => 'Typ3'} - Employee or Contract

=item {'EmpType' => 'Typ4'} - Intern

=back

=head2 Restrict by Job Category

No restriction by default. To select jobs from a specific job 
category use the following option:

=over 2

=item   {'Cats' => $job_category}

=back

See below the list of acceptable values of $job_category. Multiple selections
are possible (up to five) using a '+' sign, e.g. {'Cats' => 'Cat001+Cat002'}.

=over 2

=item * Cat001 - Accounting

=item * Cat002 - Activism

=item * Cat003 - Administration

=item * Cat004 - Advertising

=item * Cat005 - Aerospace

=item * Cat110 - Agriculture

=item * Cat006 - Air Conditioning

=item * Cat007 - Airlines

=item * Cat008 - Apartment Management

=item * Cat009 - Architecture

=item * Cat010 - Art

=item * Cat011 - Automotive

=item * Cat012 - Aviation

=item * Cat013 - Banking

=item * Cat015 - Bilingual

=item * Cat111 - Biotechnology

=item * Cat016 - Bookkeeping

=item * Cat017 - Broadcasting

=item * Cat018 - Care Giving

=item * Cat112 - Carpentry

=item * Cat113 - Chemistry

=item * Cat019 - Civil Service

=item * Cat020 - Clerical

=item * Cat021 - College

=item * Cat114 - Communication

=item * Cat022 - Computer

=item * Cat023 - Construction

=item * Cat125 - Consulting

=item * Cat024 - Counseling

=item * Cat025 - Customer Service

=item * Cat026 - Decorating

=item * Cat027 - Dental

=item * Cat028 - Design

=item * Cat029 - Driving

=item * Cat030 - Education

=item * Cat031 - Electronic

=item * Cat032 - Emergency

=item * Cat033 - Employment

=item * Cat034 - Engineering

=item * Cat035 - Entertainment

=item * Cat036 - Environmental

=item * Cat037 - Executive

=item * Cat115 - Fabrication

=item * Cat116 - Facilities

=item * Cat038 - Fashion/Apparel

=item * Cat039 - Financial

=item * Cat040 - Food Services

=item * Cat042 - Fundraising

=item * Cat044 - General Office

=item * Cat126 - Government

=item * Cat045 - Graphics

=item * Cat046 - Grocery

=item * Cat047 - Health/Medical

=item * Cat048 - Home Services

=item * Cat049 - Hospital

=item * Cat050 - Hotel/Motel

=item * Cat052 - Human Resources

=item * Cat053 - HVAC

=item * Cat054 - Import/Export

=item * Cat117 - Industrial

=item * Cat055 - Installer

=item * Cat056 - Insurance

=item * Cat118 - Internet

=item * Cat057 - Janitorial

=item * Cat119 - Journalism

=item * Cat058 - Law Enforcement

=item * Cat059 - Legal

=item * Cat060 - Maintenance

=item * Cat061 - Management

=item * Cat062 - Manufacturing

=item * Cat063 - Marketing

=item * Cat064 - Mechanical

=item * Cat065 - Media

=item * Cat066 - Merchandising

=item * Cat127 - Military

=item * Cat067 - Mining

=item * Cat128 - Mortgage

=item * Cat069 - Multimedia

=item * Cat070 - Nursing

=item * Cat071 - Nutrition

=item * Cat121 - Packaging

=item * Cat122 - Painting

=item * Cat073 - Pest Control

=item * Cat129 - Pharmaceutical

=item * Cat075 - Photography

=item * Cat076 - Plumbing

=item * Cat077 - Printing

=item * Cat078 - Professional

=item * Cat079 - Property Management

=item * Cat080 - Public Relations

=item * Cat081 - Publishing

=item * Cat082 - Purchasing

=item * Cat083 - Quality Control

=item * Cat123 - Radio

=item * Cat084 - Real Estate

=item * Cat085 - Recreation

=item * Cat086 - Research

=item * Cat087 - Restaurant

=item * Cat088 - Retail

=item * Cat089 - Sales

=item * Cat090 - Science

=item * Cat124 - Secretarial

=item * Cat091 - Security

=item * Cat092 - Services

=item * Cat093 - Shipping/Receiving

=item * Cat094 - Social Services

=item * Cat130 - Supply Chain

=item * Cat095 - Teaching

=item * Cat096 - Technical

=item * Cat097 - Telecommunications

=item * Cat098 - Telemarketing

=item * Cat099 - Television

=item * Cat100 - Textile

=item * Cat101 - Trades

=item * Cat102 - Training

=item * Cat103 - Transportation

=item * Cat104 - Travel

=item * Cat105 - Utilities

=item * Cat106 - Warehouse

=item * Cat107 - Waste Management

=item * Cat108 - Word Processing

=item * Cat109 - Work From Home

=back

=head1 AUTHOR

C<WWW::Search::HeadHunter> is written and maintained by Alexander Tkatchev
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
$VERSION = '1.01';

use Carp ();
use WWW::Search(generic_option);

sub native_setup_search
  {
  my($self, $native_query, $native_options_ref) = @_;
  $self->{agent_e_mail} = 'alexander.tkatchev@cern.ch';

  $self->user_agent('non-robot');

  if (!defined($self->{_options})) {
      $self->{'search_base_url'} = 'http://www.Headhunter.net';
      $self->{_options} = {
	  'search_url' => $self->{'search_base_url'} . '/scripts/jobquery.asp',
	  'Words' => $native_query
##	    'SID' => '',
##	    'EmpType' => 'Typ3',
##	    'Freshness' => '',
##  	    'CID' => 'US'
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
  foreach (sort keys %$options_ref) {
      next if (generic_option($_));
      $options_ref->{$_} =~ s/\+/\&$_=/g unless($_ eq 'Words');
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
  print STDERR " * HeadHunter::native_retrieve_some()\n" if($debug);
  
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

  if($response->content =~ m/No documents matched the query/) {
      print STDERR "No documents matched the query\n";
      return 0;
  }

  my $p = new HTML::TokeParser(\$response->content());
  my ($token,$tag);
  if($response->content =~ m/Next (\d+) documents/) {
      my $options;
      my $nexturl;
      PROCESS_FORM: while(1) {
	  $tag = $p->get_tag("form");
	  $nexturl = $self->{'search_base_url'} . $tag->[1]{'action'} . '?';
	  while(1) {
	      $token = $p->get_token();
	      my $type = $token->[0];
	      $tag = $token->[1];
	      next PROCESS_FORM if($type eq 'E' && $tag eq 'form');
	      next if($tag ne 'input');
	      my $value = $token->[2]{'value'};
	      last PROCESS_FORM if ($value =~ m/Next (\d+) documents/);
	      next PROCESS_FORM if ($value =~ m/Previous 25 documents/);
	      my $name = $token->[2]{'name'};
	      my $escaped = WWW::Search::escape_query($value);
	      $escaped = $value if($name eq "CiBookMark" ||
				  $name eq "CiCodepage");
#	      print STDERR "$type, $tag, $name, $value, $escaped \n";
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

  while(1) {
      $tag = $p->get_tag("td");
      my $data = $p->get_trimmed_text("/td");
      last if($data eq 'Location' ||
	      $data eq 'Company' ||
	      $data eq 'Modified');
  }

  while(1) {
      $tag = $p->get_tag("tr");
      $tag = $p->get_tag("td");
      $tag = $p->get_tag("td");
      my $location = $p->get_trimmed_text("/td");
      $tag = $p->get_tag("a");
      my $url = $self->{'search_base_url'} . $tag->[1]{href};
      my $title = $p->get_trimmed_text("/a");
      $tag = $p->get_tag("td");
      my $company = $p->get_trimmed_text("/td");
      $tag = $p->get_tag("td");
      $tag = $p->get_tag("td");
      my $date = $p->get_trimmed_text("/td");
      last unless($date =~ m|(\d+)/(\d+)/(\d+)|);
#      print STDERR "$location\t$title\t$company\t$date\t$url\n";
      $hit = new WWW::SearchResult;
      $hit->url($url);
      $hit->company($company);
      $hit->change_date($date);
      $hit->title($title);
      $hit->location($location);
      push(@{$self->{cache}}, $hit);
      $hits_found++;
  }

  return $hits_found;
} # native_retrieve_some

1;
