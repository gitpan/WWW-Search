=pod

=head1 NAME

WWW::Search::Scraper - General purpose HTML parser/scraper.


=head1 SYNOPSIS

  use WWW::Search::Scraper;

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Glenn Wood, C<glenwood@alumni.caltech.edu>.


=head1 COPYRIGHT

Copyright (C) 2001 Glenn Wood. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


####################################################################################
####################################################################################
####################################################################################
####################################################################################

package WWW::Search::Scraper;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.00';
#'

use Carp ();
use WWW::Search(generic_option);
require WWW::SearchResult;
@EXPORT_OK = qw(escape_query unescape_query generic_option strip_tags @ENGINES_WORKING trimAdmClutter addURL);

use strict;

sub generic_option 
{
    my ($option) = @_;
    return 1 if $option =~ /^scrape/;
    return WWW::Search::generic_option($option);
}

sub native_retrieve_some
{
    my ($self) = @_;
    
    # fast exit if already done
    return undef if (!defined($self->{_next_url}));
    
    # get some
    print STDERR "WWW::Search::HotJobs::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});
    my $method = $self->{'_http_method'};
    $method = 'GET' unless $method;
    my($response) = $self->http_request($method, $self->{_next_url});
    $self->{_next_url} = undef;
    $self->{response} = $response;
    return undef unless $response->is_success;
    
    my $hits_found = $self->scrape($response->content(), $self->{_debug});
    
    # sleep so as to not overload HotJobs
    $self->user_agent_delay if (defined($self->{_next_url}));
    
    return $hits_found;
}


# private
sub scrapeRow {
   my ($self, $hit, $rowDef, $row, $debug) = @_;
   $hit = new WWW::SearchResult unless $hit; # Set up a dummy stub if $hit is not defined.
   
   print "detailRow: $row\n" if $debug;
   for my $x4 ( $$rowDef[1] )
   {
      map 
      {
         my $datDef = $_;
         if ( 'TD' eq $$datDef[0] or 'DT' eq $$datDef[0] or 'DD' eq $$datDef[0] )
         {
            my $tag = $$datDef[0];
            my $datParser = $$datDef[2];
            $row =~ s-$tag\s*[^>]*>(.*?)</$tag\s*[^>]*>--si;
            my $dat = $1; 
            print "raw dat: '$dat'\n" if $debug;
            if ( $debug ) { # print ref $ aways does something screwy
               print "datParser: ";
               print ref $datParser;
               print "\n";
            };
            for my $binding ( $$datDef[1] ) {
               print "binding: $binding\n" if $debug;
               if ( $datParser ) {
                  print "parsed dat: '".&$datParser($self, $hit, $dat)."'\n" if $debug;
                  $hit->_elem($binding, &$datParser($self, $hit, $dat));
               } else {
                  print "trimmed dat: '".trimAdmClutter($dat)."'\n" if $debug;
                  $hit->_elem($binding, trimAdmClutter($dat));
               }
            }
            print "\n" if $debug;
         } else {die "Error in scaffold definition.\n";};
      } @$x4;
   }
}


# private
sub scrapeNEXT {
   my ($self, $next_url_button, $dat, $debug) = @_;

   print "next_url_button: $next_url_button\n" if $debug;
   $dat =~ m-<A\s+HREF="([^"]+)"[^>]+>$next_url_button</A>-si;
   my ($url) = new URI::URL($1, $self->{_base_url});
   $url = $url->abs;
   $self->{_next_url} = $url;
   print "NEXT_URL: $url\n" if $debug;
}


sub scrape { my ($self, $content, $debug) = @_;
   return scrapeTable($self, $content, $debug);
}

sub scrapeTable  { my ($self, $content, $debug) = @_;
   my $hits_found = 0;

   for my $x1 ( $self->{'_options'}{'scrapeFrame'}[1],  ) # <HTML> is implicit, so we don't do any processing on it.
   {
      map
      {
         if ( 'BODY' eq $$_[0] )
         {  
            my $bodyDef = $_;
            my $body = $content;
            # Process the BEGIN attribute.
            if ( $$bodyDef[1] ) {
               $body =~ s-^.*$$bodyDef[1]--s; # Make the parsing easier for scrapeTable() by stripping off the adminstrative clutter.
            }
            # Process the END attribute.
            if ( $$bodyDef[2] ) {
               $body =~ s-$$bodyDef[2]$--s; # Make the parsing easier for scrapeTable() by stripping off the adminstrative clutter.
            }
            for my $x2 ( $$bodyDef[3] ) 
            {
               map
               {
                  if ( 'TABLE' eq $$_[0] )
                  {  my $tblName = $$_[1]; print "tblName: $tblName\n" if $debug;
                     my $table = $body;
                     if ( $tblName =~ /^#(\d*)$/ )
                     {
                          for (1..$1) {
                             $table =~ s-<TABLE\s*[^>]+>(.*?)</TABLE\s*[^>]*>--si;
                          }
                          $table =~ m-<TABLE\s*[^>]+>(.*?)</TABLE\s*[^>]*>-si;
                          $table = $1;
                     } else {
                        $table =~ m-<TABLE\s+[^>]*NAME="$tblName"[^>]*>(.*?)</TABLE\s*[^>]*>-si;
                        $table = $1;
                     }
                     for my $x3 ( $$_[2] ) 
                     {
                        map 
                        {
                           if ( 'HIT*' eq $$_[0] )
                           {
                              while ( $table =~ m-(<TR\s*[^>]*>(.*?)</TR\s*[^>]*>)-si ) # while <table> has <tr>'s.
                              {
                                 my $hit = new WWW::SearchResult;
                                 my $raw = '';
                                 for my $x4 ( $$_[1] )
                                 {
                                    map {
                                       if ( 'TR' eq $$_[0] ) {
                                          my $rowDef = $_;
                                          $table =~ s-(<TR\s*[^>]*>(.*?)</TR\s*[^>]*>)--si;
                                          $raw .= $1;
                                          $self->scrapeRow($hit, $rowDef, $2, $debug);
                                       } else {die "Error in scaffold definition; expecting TR.\n";};
                                    } @$x4;
                                 }
                                 push @{$self->{cache}}, $hit;
                                 $hits_found += 1;
                              }
                           }
                           elsif ( 'TR' eq $$_[0] ) 
                           {
                              my $rowDef = $_;
                              $table =~ s-<TR\s*[^>]*>(.*?)</TR\s*[^>]*>--si;
                              $self->scrapeRow(undef, $rowDef, $1, $debug);
                           }
                           elsif ( 'NEXT' eq $$_[0] )
                           {  
                              $self->scrapeNEXT(undef, $$_[2], $table, $debug);
                           } else {die "Error in scaffold definition; expecting ( HIT* | TR | NEXT ).\n";};
                        } @$x3;
                     }
                  }
                  elsif ( 'HIT*' eq $$_[0] )
                  {
                     my $table = $body;
                     while ( $table =~ m-(<DL\s*[^>]*>(.*?)</DL\s*[^>]*>)-si ) # while <table> has <tr>'s.
                     {
                        my $hit = new WWW::SearchResult;
                        my $raw = '';
                        for my $x4 ( $$_[1] )
                        {
                           map {
                              if ( 'DL' eq $$_[0] ) {
                                 my $rowDef = $_;
                                 $table =~ s-(<DL\s*[^>]*>(.*?)</DL\s*[^>]*>)--si;
                                 $raw .= $1;
                                 $self->scrapeRow($hit, $rowDef, $2, $debug);
                              } else {die "Error in scaffold definition; expecting DL.\n";};
                           } @$x4;
                        }
                        push @{$self->{cache}}, $hit;
                        $hits_found += 1;
                     }
                  }
                  elsif ( 'COUNT' eq $$_[0] )
                  {
                    $self->approximate_result_count(0);
                    if ( $body =~ m/$$_[1]/ ) 
                        {
                            print "approximate_result_count: '$1'\n" if $debug;
                            $self->approximate_result_count($1);
                        };
                  } 
                  elsif ( 'REGEX*' eq $$_[0] ) 
                  {
                      my @ary = @$_;
                      shift @ary;
                      my $regex = shift @ary;
                      my $dat = $body;
                      while ( $dat =~ s/$regex//si ) {
                          my @dts = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
                          my $hit = new WWW::SearchResult;
                          for ( @ary ) {
                              if ( $_ eq '' ) {
                                  shift @dts;
                              }
                              elsif ( $_ eq 'url' ) {
                                  my $url = new URI::URL(shift @dts, $self->{_base_url});
                                  $url = $url->abs;
                                  $hit->add_url($url);
                              } 
                              else {
                                  $hit->_elem($_, shift @dts);
                              }
                          }
                          push @{$self->{cache}}, $hit;
                          $hits_found += 1;
                      }
                  }
                  elsif ( 'NEXT' eq $$_[0] )
                  {  
                     $self->scrapeNEXT(undef, $$_[2], $body, $debug);
                  }
                  else {die "Error in scaffold definition; got '$$_[0]', expecting ( TABLE | HIT* | COUNT | REGEX* ).\n";};
               } @$x2;
            } #else {die "Error in scaffold definition; expecting ( TABLE | HIT* ).\n";};
         } else {die "Error in scaffold definition; expecting BODY.\n";};
      } @$x1;
   }
   return $hits_found;
}



sub addURL {
   my ($self, $hit, $dat) = @_;
   
   if ( $dat =~ m-<A\s+HREF="([^"]+)"[^>]*>-si )
   {
      my ($url) = new URI::URL($1, $self->{_base_url});
      $url = $url->abs;
      $hit->add_url($url);
   } else
   {
      $hit->add_url("Can't find HREF in '$dat'");
   }

   return trimAdmClutter($dat);
}

sub trimAdmClutter { # Strip administrative clutter from $_;
   my $dat = shift;
   # This removes all HTML <tags> from the string, leaving just the data!
   $dat =~ s-<BR>-\n-gsi; # Translate <BR>'s
   $dat =~ s-</?[^>]+>--sg;
   return $dat;
}

1;
