#!/usr/local/bin/perl

# contributed from Paul Lindner <lindner@reliefweb.int>

package WWW::Search::PLweb;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

#use strict vars;
use Carp ();
require WWW::SearchResult;

my($Debug) = 1;

#private
sub native_setup_search {
    my($self, $native_query, $native_opt) = @_;
    my($native_url);
    my($default_native_url) = 
	"http://www.un.org/plweb-cgi/iopcode.p?platmode=unix&operation=query&dbgroup=un&account=_free_user_&waittime=30:seconds&dbname=gopher:web:pr:scres&query=%s";
    
    if (defined($native_opt)) {
	#print "Got " . join(' ', keys(%$native_opt)) . "\n";
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
    print "GET " . $self->{_next_url} . "\n" if ($Debug);
    my($request) = $self->HTTPrequest($self->{search_method}, $self->{_next_url});
    my($response) = $self->{user_agent}->request($request);
#    $self->{response} = $response;
    if (!$response->is_success) {
	print "Some problem\n" if ($Debug);
	return undef;
    };
    # parse the output
    use HTML::TreeBuilder;


    my $score = 800;
    my $results = $response->content();

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
	    $hit->uniformscore($score);
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
