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
$VERSION = '1.20';
#'

use Carp ();
use WWW::Search( qw(generic_option strip_tags) );
require WWW::SearchResult;
@EXPORT_OK = qw(escape_query unescape_query generic_option strip_tags trimTags @ENGINES_WORKING addURL);

use strict;

sub generic_option 
{
    my ($option) = @_;
    return 1 if $option =~ /^scrape/;
    return WWW::Search::generic_option($option);
}

sub native_setup_search
{
    my $subJob = 'Perl';
    my($self, $native_query, $native_options_ref) = @_;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 0;
    if (!defined($self->{_options})) {
	$self->{_options} = {
	    'search_url' => 'http://www.just'.$subJob.'jobs.com/cgi-bin/job-search'
        };
    };
    $self->{'_http_method'} = 'POST';
    $self->{'_options'}{'scrapeFrame'} = 
       [ 'HTML', 
         [ [ 'BODY', '<BODY', '</BODY>' , # Make the parsing easier for scrapeTable() by stripping off the adminstrative clutter.
           [ [ 'COUNT', '\d+ - \d+ of (\d+) matches' ] ,
             [ 'NEXT', 1, '<b>Next ' ] ,        # meaning how to find the NEXT button.
             [ 'TABLE', '#2' ,                     # or 'name' = undef; multiple <TABLE number=n> means n 'TABLE's here ,
               [ [ 'HIT*' ,                          # meaning the content of this array element represents hits!
#I can't do a recursive regex on <TABLE></TABLE>, yet!                  
                 [ [ 'TABLE', '#0',
                      [ [ 'TR',                        # meaning "detail*"
                      [
                        [ 'TD', 'number' ] ,            # meaning clear text binding to _elem('title').
                        [ 'TD', 'title', \&addURL ] ,   # meaning that the job description link is here, 
                        [ 'TD', 'nonsense' ] ,          #    with the title as its hypertext.
                        [ 'TD', 'description' ] ,
                      ]
                    ] ,
                    [ 'TR' ,                            # meaning "detail*"
                      [
                        [ 'TD', 'unknown' ] ,           # 
                        [ 'TD', 'unknown' ] ,           #
                        [ 'TD', 'unknown' ] ,
                        [ 'TD', 'location' ] ,
                      ]
                 ] ]
               ] ]
           ] ]
        ] ]
        ] ]
      ];

 
    my($options_ref) = $self->{_options};
    if (defined($native_options_ref)) {
	# Copy in new options.
	foreach (keys %$native_options_ref) {
	    $options_ref->{$_} = $native_options_ref->{$_};
	};
    };
    # Process the options.
    # (Now in sorted order for consistency regarless of hash ordering.)
    my($options) = '';
    foreach (sort keys %$options_ref) {
	# printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
	next if (generic_option($_));
	$options .= $_ . '=' . $options_ref->{$_} . '&';
    };
    $self->{_debug} = $options_ref->{'search_debug'};
    $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
    $self->{_debug} = 0 if (!defined($self->{_debug}));
    
    # Finally figure out the url.
    $self->{_base_url} = 
	$self->{_next_url} =
            	$self->{_options}{'search_url'} .
        	    "?" . $options .
            	"KEYWORDS=" . $native_query;
# for Testing
$self->{_next_url} = 'http://www.justperljobs.com/jperj.nsf/SearchResults?OpenForm&SKIL=01&POST=&VISA=&CONT=&ENTL=&STRT=&COMP=&LOCA=US-CA-Silicon%Valley/San%Jose&KEYW=XML&LOGF=AND&NEXT=1';    
    print STDERR $self->{_base_url} . "\n" if ($self->{_debug});
}



sub native_retrieve_some
{
    my ($self) = @_;
    
    # fast exit if already done
    return undef if (!defined($self->{_next_url}));
    
    # get some
     if ($self->{_debug}) {
         my $obj = ref $self;
         print STDERR "$obj::native_retrieve_some: fetching " . $self->{_next_url} . "\n";
     }
    my $method = $self->{'_http_method'};
    $method = 'GET' unless $method;
    my($response) = $self->http_request($method, $self->{_next_url});
    $self->{_next_url} = undef;
    $self->{response} = $response;
    return undef unless $response->is_success;
    
    my $hits_found = $self->scrape($response->content(), $self->{_debug});

    # sleep so as to not overload the engine
    $self->user_agent_delay if (defined($self->{_next_url}));
    
    return $hits_found;
}



# Public
sub scrape { my ($self, $content, $debug) = @_;
   return scraper($self, $self->{'_options'}{'scrapeFrame'}[1], \$content, undef, $debug);
}

# private
sub scraper { my ($self, $scaffold_array, $content, $hit, $debug) = @_;
	# Here are some variables that we use frequently done here.
    my $total_hits_found = 0;
    
    my ($sub_content, $next_scaffold);


SCAFFOLD: for my $scaffold ( @$scaffold_array ) {
        my $tag = $$scaffold[0];

#   print "TAG: $tag\n";

        # 'HIT*' is special since it has pre- and post- processing (adding the hits to the hit-list).
        # All other tokens simply process data as it moves along, then they're done,
        #  so they will do a set up, then pass along to recurse on scraper() . . .
        if ( 'HIT*' eq $tag )
        {
            my $hit;
            do 
            {
                if ( $hit && $self->filter($hit, $debug) )
                {
                    push @{$self->{cache}}, $hit;
                    $total_hits_found += 1;
                }
                $hit = new WWW::SearchResult;
            } while ( $self->scraper($$scaffold[1], $content, $hit, $debug) );
            next SCAFFOLD;
        }
    
        elsif ( 'BODY' eq $tag )
        {  
           # Process the BEGIN attribute.
           if ( $$scaffold[1] ) {
                next SCAFFOLD unless $$content =~ s-^.*?$$scaffold[1]--si; # Strip off the adminstrative clutter at the beginning.
           }
           # Process the END attribute.
           if ( $$scaffold[2] ) {
                next SCAFFOLD unless $$content =~ s-$$scaffold[2].*$--si; # Strip off the adminstrative clutter at the end.
           }
           $sub_content = $$content;
           $next_scaffold = $$scaffold[3];
        }
    	
        elsif ( 'COUNT' eq $tag )
    	{
            next SCAFFOLD;
            # this does something really weird to the Perl parser, and we get really weird results (fractional dimensional recursion).
            $self->approximate_result_count(0);
    		if ( $$content =~ m/$$scaffold[1]/ )
    		{
    			print STDERR  "approximate_result_count: '$1'\n" if $debug;
    			$self->approximate_result_count ($1);
                next SCAFFOLD;
    		}
            else {
                print STDERR "Can't find COUNT: '$$scaffold[1]'\n" if $debug;
            }
    	} 
        elsif ( 'NEXT' eq $tag )
        {
            my $next_url_button = $$scaffold[2];
    
            print STDERR  "next_url_button: $next_url_button\n" if $debug;
            if ( $$content =~ m-<A\s+HREF="([^"]+)"[^>]*>$next_url_button</A>-si )
            {
                my ($url) = new URI::URL($1, $self->{_base_url});
                $url = $url->abs;
                $self->{_next_url} = $url;
                print STDERR  "NEXT_URL: $url\n" if $debug;
            } else
            {
                print STDERR  "Can't find NEXT button, '$next_url_button', in '$$content'\n" if $debug > 1;
            }
        }
        # The rest of these tokens will set parameters for the next recursion into scraper()
        elsif ( 'HTML' eq $tag )
        {
            $$content =~ m-<HTML>(.*)</HTML>-si;
            $sub_content = $1;
            $next_scaffold = $$scaffold[1];
        }
    	elsif ( $tag =~ m/^(TABLE|TR|DL|FORM)$/ )
    	{
            my $tagLength = length $tag + 2;
            my $elmName = $$scaffold[1];
            $elmName = '#0' unless $elmName;
            if ( 'ARRAY' eq ref $$scaffold[1] )
            {
                $next_scaffold = $$scaffold[1];
            }
            elsif ( $elmName =~ /^#(\d*)$/ )
    		{
    			print STDERR  "elmCount: $1\n" if $debug;
                for (1..$1)
    			{
                    $self->getMarkedText($tag, $content); # and throw it away.
    			}
                $next_scaffold = $$scaffold[2];
            }
            else {
                print STDERR  "elmName: $elmName\n" if $debug;
                $next_scaffold = $$scaffold[2];
                die "Element-name form of <$tag> is not implemented, yet.";
            }
            next SCAFFOLD unless $sub_content = $self->getMarkedText($tag, $content); # and throw it away.
        }
    	elsif ( 'TD' eq $tag or 'DT' eq $tag or 'DD' eq $tag )
        {
    		next SCAFFOLD unless ( $$content =~ s-(<$tag\s*[^>]*>(.*?)</$tag\s*[^>]*>)--si );
    		$sub_content = $2;
    		$next_scaffold = $$scaffold[1];
    		if ( 'REF' ne ref $next_scaffold  ) # if next_scaffold is a ref, then we'll recurse (below)
            {
                my $binding = $next_scaffold;
               my $datParser = $$scaffold[2];
               print STDERR  "raw dat: '$sub_content'\n" if $debug;
               if ( $debug ) { # print ref $ aways does something screwy
                  print STDERR  "datParser: ";
                  print STDERR  ref $datParser;
                  print STDERR  "\n";
               };
               $datParser = \&WWW::Search::Scraper::trimTags unless $datParser;
               print STDERR  "binding: '$binding', " if $debug;
               print STDERR  "parsed dat: '".&$datParser($self, $hit, $sub_content)."'\n" if $debug;
                if ( $binding eq 'url' )
                {
                    my $url = new URI::URL(&$datParser($self, $hit, $sub_content), $self->{_base_url});
                    $url = $url->abs;
                    $hit->add_url($url);
                } 
                else {
                    $hit->_elem($binding, &$datParser($self, $hit, $sub_content));
                }
            }
            $total_hits_found = 1;
            next SCAFFOLD;
        }
        elsif ( 'A' eq $tag ) 
        {
            if ( $$content =~ s-<A\s+HREF="([^"]+)"[^>]*>(.*?)</a>--si )
            {
                print "<A> binding: $$scaffold[2]: '$2', $$scaffold[1]: '$1'\n" if $debug;
                $hit->_elem($$scaffold[2], $2);
                my $lbl = $$scaffold[1];
               my ($url) = new URI::URL($1, $self->{_base_url});
               $url = $url->abs;
               if ( $lbl eq 'url' ) {
                    $hit->add_url($url);
               }
               else {
                   $hit->_elem($lbl, $url);
               }
            } else
            {
               $hit->add_url("Can't find HREF in '$$content'");
               $hit->_elem($$scaffold[2], "Can't find <A> in '$$content'");
            }

        }
        elsif ( 'REGEX' eq $tag ) 
        {
            my @ary = @$scaffold;
            shift @ary;
            my $regex = shift @ary;
            if ( $$content =~ s/$regex//si )
            {
                my @dts = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
                for ( @ary ) 
                {
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
                $total_hits_found += 1;
            }
            next SCAFFOLD;
        } elsif ( $tag eq 'TRACE' )
        {
            print "TRACE:\n'$$content'\n";
            $total_hits_found += $$scaffold[1];
        } elsif ( $tag eq 'CALLBACK' ) {
            &{$$scaffold[1]}($self, $hit, $content, $debug);
        } else {
            die "Unrecognized tag: '$tag'";
        }

        # So it's all set up to recurse to the next layer - - -
        $total_hits_found += $self->scraper($next_scaffold, \$sub_content, $hit, $debug);
    }
    return $total_hits_found;
}




# Returns the marked up text from the referenced string, as designated by the given tag.
# This algorithm extracts the contents of the first <$tag> element it encounters,
#   taking into consideration that it may contain <$tag> elements within it.
# It removes the marked text from the original string, strips off the markup tags,
#   and returns that result.
# (if wantarray, will return result and first tag, with brackets removed)
#
sub getMarkedText {
    my ($self, $tag, $content) = @_;
    
    my $eidx = 0;
    my $sidx = 0;
    my $depth = 0;

    while ( $$content =~ m-<(/)?$tag[^>]*?>-gsi ) {
        if ( $1 ) { # then we encountered an end-tag
            $depth -= 1;
            if ( $depth < 0 ) {
                # . . . then somehow we've stumbled into the midst of a table whose end-tag
                #   has just been encountered - let's be generous and start over.
                my $eidx = 0;
                my $sidx = 0;
                my $depth = 0;
            }
            elsif ( $depth == 0 ) { # we've counted as many end-tags as start-tags; we're done!
                $eidx = pos $$content;
                last;
            }
        } else # we encountered a start-tag
        {
            $depth += 1;
            $sidx = length $` unless $sidx; 
        }
    }
    
    my $rslt = substr $$content, $sidx, $eidx - $sidx, '';
    $rslt =~ m-^<($tag[^>]*?)>(.*?)</$tag\s*[^>]*?>$-si;
    return ($2, $1) if wantarray;
    return $2;
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

   return trimTags($self, $hit, $dat);
}


sub trimTags { # Strip tag clutter from $_;
    my ($self, $hit, $dat) = @_;
   # This simply reorganizes the parameter list from the datParser form.
    return strip_tags($dat);
}


# This method lets you make one last filtering of the hit before
#  it is actually added to the hit list. 
# You may also make last minute adjustments to the attributes of $hit.
# Return true to add to hit list, false to not.
sub filter {
    my ($self, $hit, $debug) = @_;
    return 1;
}

1;
