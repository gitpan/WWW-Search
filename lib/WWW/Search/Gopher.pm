#!/usr/local/bin/perl

# contributed from Paul Lindner <lindner@reliefweb.int>

package WWW::Search::Gopher;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

#use strict vars;
use Carp ();
require WWW::SearchResult;

my($debug) = 0;

sub native_setup_search {
    my($self, $native_query, $native_opt) = @_;
    my($native_url);
    my($default_native_url) =
	"gopher://info2.itu.ch:70/7waissrc%3a/.1/TERMITE/english/.waisdb/TERMITE_english?%s";
    
    if (defined($native_opt)) {
	# Process options..
	# Substitute query terms for %s...

	if ($self->{'search_url'} && $native_opt->{'search_args'}) {
	    $native_url = $native_opt->{'search_url'} . "?" . $native_opt->{'search_args'};
	}
    } 

    
    $native_url = $default_native_url if (!$native_url);

    $native_url =~ s/%s/$native_query/g; # Substitute search terms...

    $self->user_agent();
    $self->{_next_to_retrieve} = 0;
    $self->{_base_url} = $self->{_next_url} = $native_url;
}

# private
sub native_retrieve_some
{
    my ($self) = @_;
    my ($hit)  = ();
    my ($hits_found) = 0;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    my($url, $search) = split(/\?/, $self->{_next_url});
    my $url = new URI::URL($url);
    &GopenServer($url->host, $url->port);
    my $send = $url->path . "\t$search";
    $send =~s/^..//;
    alarm(10);
    &Gsend($send);
    alarm(0);

    my($self) = @_;
    my(%srchitem);
    my(@entries);
    
    $i = 0;
    while ($_ = &Grecv) {
	last if (/^\.$/);
	my($title, $path, $host, $port, $xtra) = split(/\t/);
	$type = substr($title, 0,1);
	$title =~ s/^.//;

	$hits_found++;
	$score = 800  - (20 * $hits_found);

	my($hit) = new WWW::SearchResult;
	my $link = "gopher://$host:$port/$type$path";
	$link =~ s/ /%20/g;
 	$hit->add_url($link);
	$hit->title($title);
	$hit->score($score);
	$hit->normalized_score($score);
	$hit->ref($self->{'search_ref'});

	push(@{$self->{cache}}, $hit);
		
    }

    $self->approximate_result_count($hits_found);
    $self->{_next_url} = undef;
    return($hits_found);
}


use Socket;

sub GopenServer {

    local($server,$port) = @_;
    local($type, $name, $aliases, $len, $saddr);

    $sin = sockaddr_in($port,inet_aton("$server"));
    $proto = getprotobyname('tcp');

    socket(GSERVER, PF_INET, SOCK_STREAM, $proto) || return(-1);
      

    connect(GSERVER, $sin)  || return(-1);
    select(GSERVER); $| = 1; select(STDOUT); $| = 1;
    return(0);
}

sub GcloseServer {
    close(GSERVER);
}

sub Gsend { 
    print "send -> |$_[0]|\n" if (defined($Gdebug));
    print GSERVER "$_[0]\r\n"; 
}

sub Grecv { 
  local ($_); 
  $_= <GSERVER>; 
  s/\n$//;
  s/\r$//;
  print "recv -> |$_|\n" if (defined($Gdebug));
  return $_; 
}


1;
