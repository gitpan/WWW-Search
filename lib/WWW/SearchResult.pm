#!/usr/local/bin/perl -w

#
# SearchResult.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: SearchResult.pm,v 1.10 1999/04/26 21:20:48 johnh Exp $
#
# Copyright (c) 1996 University of Southern California.
# All rights reserved.                                            
#                                                                
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation, advertising
# materials, and other materials related to such distribution and use
# acknowledge that the software was developed by the University of
# Southern California, Information Sciences Institute.  The name of the
# University may not be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 


package WWW::SearchResult;

=head1 NAME

WWW::SearchResult - class for results returned from WWW::Search

=head1 SYNOPSIS

    require WWW::Search;
    require WWW::SearchResult;
    $search = new WWW::Search;
    $search->native_query(WWW::Search::escape_query($query));
    # get first result
    $result = $search->next_result();


=head1 DESCRIPTION

A framework for returning the results of C<WWW::Search>.


=head1 SEE ALSO

L<WWW::Search>

=head1 REQUIRED RESULTS

The particular fields returned in a result are back-end
(search-engine) dependent.  However, all search engines are required 
to return a url and title.
(This list may grow in the future.)


=head1 METHODS AND FUNCTIONS

=cut

#####################################################################

require LWP::MemberMixin;
@ISA = qw(LWP::MemberMixin);

use Carp ();
# use HTTP::Status 'RC_INTERNAL_SERVER_ERROR';

# my %ImplementedBy = (); # scheme => classname


my($SEARCH_UNSPECIFIED, $SEARCH_SPECIFIED, $SEARCH_UNDERWAY, $SEARCH_DONE) = (1..10);


=head2 new

To create a new WWW::SearchResult, call
    $search = new WWW::SearchResult();

=cut

sub new
{ 
    my($class) = @_;

    my $self = bless {
    }, $class;
    $self->{urls} = ();
    return $self;
}


=head2 url

Return the primary URL.
Note that there may be a list of urls, see also methods
C<urls> and C<add_url>.
Nothing special is guaranteed about the primary URL
other than that 
it's the first one returned by the back end.

Every result is required to have at least one URL.

=cut
#'
sub url {
    my($self) = shift @_;
    return ${$self->{urls}}[0] if ($#_ == -1);
    unshift @{$self->{urls}}, $_[0];
    return ${$self->{urls}}[0];
};

sub _elem_array {
    my($self) = shift @_;
    my($elem) = shift @_;
    return wantarray ? @{$self->{$elem}} : $self->{$elem}
        if ($#_ == -1);
    if (ref($_[0])) {
        $self->{$elem} = $_[0];
    } else {
	$self->{$elem} = ();
	push @{$self->{$elem}}, @_;
    };
    # always return array refrence
    return $self->{$elem};
}
sub _add_elem_array {
    my($self) = shift @_;
    my($elem) = shift @_;
    push(@{$self->{$elem}}, @_);
};


=head2 urls

Return a reference to an array of urls.
There is also a primary URL (C<url>).
See also C<add_url>.

=head2 add_url

Add a URL to the list.


=head2 related_urls, add_related_url, related_titles, add_related_title

Analgous to urls, these functions provide lists of related URLs
and their titles.  These point to things the search engine thinks
you might want (for example, see Infoseek).

=cut
sub urls { return shift->_elem_array('urls', @_); }
sub add_url { return shift->_add_elem_array('urls', @_); }
sub related_urls { return shift->_elem_array('related_urls', @_); }
sub add_related_url { return shift->_add_elem_array('related_urls', @_); }
sub related_titles { return shift->_elem_array('related_titles', @_); }
sub add_related_title { return shift->_add_elem_array('related_titles', @_); }

=head2 title, description, score, change_date, index_date, size, raw

Set or get attributes of the result.

None of these attributes is guaranteed to be provided by 
a given back-end.  If an attribute is not provided
its method will return C<undef>.

Typical contents of these attributes:

=over 8
=item title
The result's title (typically that provided by the ``TITLE'' HTML command) .

=item description
A brief description of result.
Often the first few sentences of the document.

=item score
A back-end specific, numeric ``score'' of the search result.
The exact range of scores is search-engine specific.
Usually larger scores are better, but this is no longer required.
See normalized_score for a back-end independent score.

=item normalized_score
A back-end independent score of the search result.
The range of this score is between 0 and 1000.
Higher values indicate better quality results.

=item change_date
When the result was last changed.

=item index_date
When the search engine indexed the result.

=item size
The size of the result, in bytes.

=item raw
The raw HTML for the entire result.
Raw should be exactly the raw HTML for one entry.
It shouldn't include list or table setup commands (like the ul tag),
but it may include list or table item commands (like li).
Whether raw returns a list entries, table entries, or just br or unformatted
HTML is search-engine dependent.

=back

=cut
#'
sub title { return shift->_elem('title', @_); }
sub description { return shift->_elem('description', @_); }
sub score { return shift->_elem('score', @_); }
sub normalized_score { return shift->_elem('normalized_score', @_); }
sub change_date { return shift->_elem('change_date', @_); }
sub index_date { return shift->_elem('index_date', @_); }
sub size { return shift->_elem('size', @_); }
sub raw { return shift->_elem('raw', @_); }


1;
