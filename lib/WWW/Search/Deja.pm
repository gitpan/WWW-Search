# Deja.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: Deja.pm,v 1.1 1999/09/17 17:40:42 mthurn Exp $

=head1 NAME

WWW::Search::Deja - class for www.deja.com searching

=head1 SYNOPSIS

  require WWW::Search;
  $search = new WWW::Search('Deja');
  my $sQuery = WWW::Search::escape_query("stupid Virginia school closings");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class implements the Deja.com search (specializing WWW::Search).
It handles making and interpreting Deja.com searches
F<http://www.deja.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 TESTING

This module just points everything to Dejanews.pm; there is no local testing.

=head1 AUTHOR

C<WWW::Search::Deja> 
was written by Martin Thurn <MartinThurn@iname.com> 

=cut

#####################################################################

package WWW::Search::Deja;

require WWW::Search::Dejanews;
@ISA = qw(WWW::Search::Dejanews);

$VERSION = '2.04';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = '1';

# ALL the work is done by Dejanews.pm!

1;
