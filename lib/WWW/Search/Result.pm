
# $Id: Result.pm,v 1.2 2004/10/14 03:22:58 Daddy Exp $

=head1 NAME

WWW::Search::Result - class for results returned from WWW::Search

=head1 DESCRIPTION

This module is just a synonym for L<WWW::SearchResult>

=head1 AUTHOR

Martin Thurn

=cut

package WWW::Search::Result;

use WWW::SearchResult;

use strict;
use vars qw( @ISA $VERSION );

@ISA = qw( WWW::SearchResult );
$VERSION = do { my @r = (q$Revision: 1.2 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

1;
