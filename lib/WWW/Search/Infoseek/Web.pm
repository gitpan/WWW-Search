# Web.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: Web.pm,v 1.10 1999/06/30 15:35:19 mthurn Exp $

=head1 NAME

WWW::Search::Infoseek::Web - class for Infoseek Web searching

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Infoseek::Web');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class implements the Infoseek Web search
(specializing Infoseek and WWW::Search).
It handles making and interpreting Infoseek Web searches
F<http://www.infoseek.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 TESTING

This module adheres to the WWW::Search test mechanism.
See $TEST_CASES below.

=head1 AUTHOR

C<WWW::Search::Infoseek::Web> 
was written by Martin Thurn <MartinThurn@iname.com> 

=cut

#####################################################################

package WWW::Search::Infoseek::Web;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Infoseek Exporter);
$VERSION = '1.10';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Infoseek::Web', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_BY_COUNTING, 0);
&test('Infoseek::Web', '$MAINTAINER', 'one_page', 'Mar'.'tin Thurn AND St'.'ar Wa'.'rs', \$TEST_RANGE, 2,24);
&test('Infoseek::Web', '$MAINTAINER', 'two_page', 'Gre'.'edo AND collecti'.'ble', \$TEST_GREATER_THAN, 25);
ENDTESTCASES

use WWW::Search::Infoseek;

# Infoseek.pm does all the work by default!

1;
