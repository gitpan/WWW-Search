#!/usr/local/bin/perl -w

#
# SearchResult.pm
# by John Heidemann
# Copyright (C) 1996 by USC/ISI
# $Id: SearchResult.pm,v 1.3 1996/10/03 22:06:10 johnh Exp $
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

=head1 DESCRIPTION

A framework for returning the results of C<WWW::Search>.


=head1 SEE ALSO

L<WWW::Search>


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

Return url.  Note that there may be a list of urls, see also methods
C<urls> and C<add_url>.

=cut
sub url {
    my($self) = shift @_;
    return ${$self->{urls}}[0] if ($#_ == -1);
    unshift @{$self->{urls}}, $_[0];
    return ${$self->{urls}}[0];
};

=head2 urls

Return a reference to an array of urls.
There is also a distinguished URL (C<url>).
See also C<add_url>.

=cut
sub urls {
    my($self) = shift @_;
    return wantarray ? @{$self->{urls}} : $self->{urls}
        if ($#_ == -1);
    if (ref($_[0])) {
        $self->{urls} = $_[0];
    } else {
	$self->{urls} = ();
	push @{$self->{urls}}, @_;
    };
    # always return array refrence
    return $self->{urls};
}

=head2 add_url

Add a URL to the list.

=cut
sub add_url {
    my($self) = shift @_;
    push(@{$self->{'urls'}}, @_);
};

=head2 title, description

Set or get attributes of the result.
In the future, these attributes might expand to include
size and change-date.

=cut
sub title { return shift->_elem('title', @_); }
sub description { return shift->_elem('description', @_); }




1;
