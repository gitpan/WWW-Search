
# $Id: Result.pm,v 1.4 2007/06/03 19:31:27 Daddy Exp $

=head1 NAME

WWW::Search::Result - class for results returned from WWW::Search

=head1 DESCRIPTION

This module is just a synonym for L<WWW::SearchResult>

=head1 AUTHOR

Martin Thurn

=cut

package WWW::Search::Result;

use strict;

use base 'WWW::SearchResult';

our
$VERSION = do { my @r = (q$Revision: 1.4 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

1;

__END__

