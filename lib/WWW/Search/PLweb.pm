#!/usr/local/bin/perl

#
# PLweb.pm
# by Paul Lindner <lindner@itu.int>
# Copyright (C) 1997 by the UN Administrative Committee on Coordination (ACC)
#

package WWW::Search::PLweb;

=head1 NAME

WWW::Search::PLweb - class for searching PLS PLweb search engine

=head1 DESCRIPTION

This class is a PLweb specialization of WWW::Search.
It queries and interprets searches based on PLweb, by PLS 
F<http://www.pls.com/>.

This class exports no public interface; all interaction should be
done through WWW::Search objects.

This software assumes that you're using the default output format for
a PLweb search.  It should look like this:

  VAL DOCUMENT DB SIZE
  ------------------------------------------------------------------
  388 Document1 foo 1122 ...

=head1 OPTIONS

This search supports standard WWW::Search arguments

=over 8

=item search_url

The PLweb URL to search.  On unix this usually looks like 
http://somehost/cgi-bin/iopcode.pl

=item search_args

The arguments used for the search engine, separate them by &.

=back

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>,

=head1 AUTHOR

C<WWW::Search::PLweb> is written by Paul Lindner, <lindner@itu.int>
saving to disk.

=head1 BUGS

Things not supported: $result->raw(), options: search_debug.

=head1 COPYRIGHT

Copyright (c) 1997 by the United Nations Administrative Committee 
on Coordination (ACC)

All rights reserved.

=cut
#' for emacs font-lock

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

#use strict vars;
use Carp ();
require WWW::SearchResult;

my($Debug) = 0;

#private
sub native_setup_search {
    my($self, $native_query, $native_opt) = @_;
    my($native_url);
    my($default_native_url) = 
	"http://www.un.org/plweb-cgi/iopcode.pl?platmode=unix&operation=query&dbgroup=un&account=_free_user_&waittime=10 seconds&dbname=gopher:web:pr:scres&query=%s";
    
    if (defined($native_opt)) {
	#print "Got " . join(' ', keys(%$native_opt)) . "\n";
	# Process options..
	# Substitute query terms for %s...

	if ($self->{'search_url'} && $native_opt->{'search_args'}) {
	    $native_url = $native_opt->{'search_url'} . "?" . $native_opt->{'search_args'};
	}
    } 

    $native_url = $default_native_url if (!$native_url);

    ## Change behaviour depending on 'search_how'
    if ($self->{'search_how'} eq 'match_any') {
	## change separator to or, or add it..
	$native_url =~ s/separator=[^&]+/separator=or/ig;
	if ($native_url !~ /separator=/) {
	    $native_url .= "&separator=or";
	}

    } elsif ($self->{search_how} eq 'match_all') {
	## change separator to and, or add it..
	$native_url =~ s/separator=[^&]+/separator=and/ig;
	if ($native_url !~ /separator=/) {
	    $native_url .= "&separator=and";
	}
    } elsif ($self->{search_how} eq 'match_phrase') {
	## change separator to adj, or add it..
	$native_url =~ s/separator=[^&]+/separator=adj/ig;
	if ($native_url !~ /separator=/) {
	    $native_url .= "&separator=adj";
	}
    }

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
    print "GET " . $self->{_next_url} . "\n" if ($Debug);
    my($request) = $self->HTTPrequest($self->{search_method}, $self->{_next_url});
    my($response) = $self->{user_agent}->request($request);
    $self->{response} = $response;
    if (!$response->is_success) {
	print "Some problem\n" if ($Debug);
	return undef;
    };
    print "Got something...\n" if ($Debug);
    # parse the output
    use HTML::TreeBuilder;


    my $score = 800;
    my $results = $response->content();
    #print "$results" if ($Debug);
    if (!$results) {
	return(undef);
    }
    
    my (@lines) = split(/\n/, $results);
    my ($docs_found);
    my ($score_ratio) = 0;

    while ($#lines > -1)  {
	$_ = shift(@lines);
	s,\s+, ,g;
	if (m,(\d+) documents found,) {
	    $docs_found = $1;
	} elsif (m,^\s*(\d+) <A HREF=\"([^\"]+)\">(.*)</A>.*\s(\d+).*$,) {
	    if (($1 > 0) && ($score_ration == 0)) {
		if ($1 > 900) {
		    $score_ratio = 1000/$1;
		} else {
		    $score_ratio = (1000/$1) * .9;
		}
	    }	    	    
	    #print "Make abs, " . $self->{_next_url} . "\n  for $2\n";
	    my($linkobj) = $self->absurl($self->{_next_url}, $2);
	    my($hit) = new WWW::SearchResult;
	    $hit->add_url($linkobj->abs->as_string);
	    $hit->title($3);
	    $hit->size($4);
	    #print "Found a link $1, $2, $3, $4\n";
	    $hit->score($1 * $score_ratio);
	    $hit->ref($self->{'search_ref'});
	    push(@{$self->{cache}}, $hit);
	}
    }
    $self->approximate_result_count($docs_found);
    $self->{_next_url} = undef;
    return($docs_found);

    my($h) = new HTML::TreeBuilder;
    $h->parse($results);

    for (@{ $h->extract_links(qw(a)) }) {
	my($link, $linkelem) = @$_;
	
      if (($linkelem->parent->starttag() =~ /<P>/) &&
	  ($linkelem->parent->endtag()   =~ m,</P>,)) {

	    my($linkobj)       = $self->absurl($self->{_next_url}, $link);

	    $hits_found++;

	    my($hit) = new WWW::SearchResult;
	    $hit->add_url($linkobj->abs->as_string());
	    $hit->title(join(' ',@{$linkelem->content}));
	    $hit->score($score);
	    $hit->normalized_score($score);
	    $hit->ref($self->{'search_ref'});

	    push(@{$self->{cache}}, $hit);
		
	    #$srchitem{'origin'} = $self->{'myurl'};
	    #$srchitem{'index'}  = $self->{'index'};

	    $score = int ($score * .95);
	}
    }
    $self->approximate_result_count($hits_found);
    $self->{_next_url} = undef;
    return($hits_found);
}



1;
