# EuroSeek.pm
# by Jim Smyser
# Copyright (c) 2000 by Jim Smyser 
# $Id: Euroseek.pm,v 1.1 2000/02/08 16:10:17 mthurn Exp $

package WWW::Search::a;

=head1 NAME

WWW::Search::EuroSeek - class for searching EuroSeek

=head1 OPTIONS

Example:
-o ilang=english -o domain=ru


LANG:
<option value="world">any language
<option value="bulgarski">Bulgarian
<option value="cêch">Czech
<option value="welsh">Welsh
<option value="dansk">Danish
<option value="deutsch">German
<option value="eesti">Estonian
<option value="elivika">Greek
<option value="english">English
<option value="español">Spanish
<option value="esperanto">Esperanto
<option value="français">French
<option value="hrvatski">Croatian
<option value="íslensku">Icelandic
<option value="italiano">Italian
<option value="latviski">Latvian
<option value="lietuvisku">Lithuanian
<option value="magyar">Hungarian
<option value="makedonski">Macedonian
<option value="nederlands">Dutch
<option value="norsk">Norwegian
<option value="polski">Polish
<option value="português">Portuguese
<option value="romana">Romanian
<option value="russkij">Russian
<option value="slovak">Slovak
<option value="slovensk">Slovenian
<option value="suomi">Finnish
<option value="svenska">Swedish
<option value="turkce">Turkish

DOMAIN:
<option value="world">=European Countries=
<option value="al">Albania
<option value="ad">Andorra
<option value="at">Austria
<option value="be">Belgium
<option value="ba">Bosnia/Herzegowina
<option value="bg">Bulgaria
<option value="hr">Croatia
<option value="cy">Cyprus
<option value="cz">Czech Republic
<option value="dk">Denmark
<option value="ee">Estonia
<option value="fi">Finland
<option value="fr">France
<option value="de">Germany
<option value="gr">Greece
<option value="gl">Greenland
<option value="hu">Hungary
<option value="is">Iceland
<option value="ie">Ireland
<option value="il">Israel
<option value="it">Italy
<option value="lv">Latvia
<option value="li">Liechtenstein
<option value="lt">Lithuania
<option value="lu">Luxembourg
<option value="mk">Macedonia
<option value="mc">Monaco
<option value="nl">Netherlands
<option value="no">Norway
<option value="pl">Poland
<option value="pt">Portugal
<option value="ro">Romania
<option value="ru">Russian Federation
<option value="sk">Slovakia Republic
<option value="si">Slovenia
<option value="es">Spain
<option value="se">Sweden
<option value="ch">Switzerland
<option value="tr">Turkey
<option value="ua">Ukraine
<option value="gb">United Kingdom (GB)
<option value="uk">United Kingdom (UK)
<option value="va">Vatican State
<option value="yu">Federal Republic Yugoslavia

<option value="">=Regions=
<option value="scandinavia">Scandinavia
<option value="europe">Europe
<option value="namerica">North America
<option value="samerica">South America
<option value="asia">Asia
<option value="au">Australia
<option value="africa">Africa


<option value="">=Special Domains=
<option value="com">Companies
<option value="mil">Military
<option value="edu">Universities
<option value="gov">Government
<option value="org">Organizations
<option value="net">Networks

=cut
#'

#####################################################################
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.01';

use Carp ();
use WWW::Search(qw(generic_option strip_tags));
use URI::Escape;

require WWW::SearchResult;

sub native_setup_search {
   my($self, $native_query, $native_options_ref) = @_;
   $self->{_debug} = $native_options_ref->{'search_debug'};
   $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
   $self->{_debug} = 0 if (!defined($self->{_debug}));

   #Define default number of hit per page
   $self->{'_hits_per_page'} = 100;
   $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
   $self->user_agent('user');
   $self->{_next_to_retrieve} = 0;
   if (!defined($self->{_options})) {
     $self->{'search_base_url'} = 'http://www.euroseek.com';
     $self->{_options} = {
         'search_url' => 'http://www.euroseek.com/query',
         'lang' => 'world',
         'query' => $native_query,
           };
           }
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

  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $self->hash_to_cgi_string($self->{_options});
   } # native_setup_search

# private
sub native_retrieve_some
    {
    my ($self) = @_;
    print STDERR "**Getting Some**\n" if $self->{_debug};
    
    # Fast exit if already done:
    return undef if (!defined($self->{_next_url}));
    $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
    
    # Get some:
    print STDERR "**Requesting (",$self->{_next_url},")\n" if $self->{_debug};
    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) 
      {
      return undef;
      }
    $self->{'_next_url'} = undef;
    print STDERR "**Found Some\n" if $self->{_debug};
    # parse the output
    my ($HEADER, $HITS, $DESC, $LOC, $DATE) = qw(HE HI DE LO DA);
    my $state = $HEADER;
    my $hit = ();
    my $hits_found = 0;
    foreach ($self->split_lines($response->content()))
      {
     next if m@^$@; # short circuit for blank lines
     print STDERR " * $state ===$_=== " if 2 <= $self->{'_debug'};
   if (m|\(of&nbsp;(\d+)\)|i) {
       $self->approximate_result_count($1);
       print STDERR "**Approx. Count\n" if ($self->{_debug});
       $state = $HITS;
       } 
   if ($state eq $HITS && 
       m|<TD COLSPAN.*?><.*?>.*?<A HREF=".*?"><IMG SRC.*?>.*?<A HREF=".*?url=(.*)">(.*)</A></FONT></TD>|i) 
       {
       print STDERR "**Found a URL\n" if 2 <= $self->{_debug};
	   my ($url,$title) = ($1,$2);
         if (defined($hit)) 
         {
        push(@{$self->{cache}}, $hit);
         };
       $hit = new WWW::SearchResult;
       $hit->add_url(uri_unescape($url));
       $hits_found++;
       $hit->title(strip_tags($title));
       $state = $DESC;
       } 
   elsif ($state eq $DESC && 
       m|<TD width.*?><FONT FACE.*?>(.*)</FONT></TD>|i) 
       {
       $hit->description($1);
       $state = $LOC;
       } 
   elsif ($state eq $LOC && 
       m|<TD ALIGN.*?><.*?>&nbsp;\[\s(.*)\]&nbsp;</FONT><BR>|i) 
       {
       $hit->location(strip_tags($1));
       $state = $DATE;
       } 
   elsif ($state eq $DATE && 
       m|<FONT COLOR.*?>&nbsp;\[\s(.*)$|i) 
       {
       $hit->index_date($1);
       $state = $HITS;
	   }
   elsif ($state eq $HITS && m|<b><A HREF="(.*)">Next.*?</A>|i) 
       {
       print STDERR "**Found 'next' Tag\n" if 2 <= $self->{_debug};
       my $sURL = $1;
       $self->{'_next_url'} = $self->{'search_base_url'} . $sURL;
       print STDERR " **Next Tag is: ", $self->{'_next_url'}, "\n" if 2 <= $self->{_debug};
       $state = $HITS;
       } 
     else 
       {
       print STDERR "**Nothing Matched\n" if 2 <= $self->{_debug};
       }
   } if (defined($hit)) {
     push(@{$self->{cache}}, $hit);
     } 
   return $hits_found;
   } # native_retrieve_some
1;
