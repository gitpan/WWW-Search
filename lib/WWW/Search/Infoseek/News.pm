# News.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: News.pm,v 1.9 1999/06/30 15:09:12 mthurn Exp $

=head1 NAME

WWW::Search::Infoseek::News - class for Infoseek News searching

=head1 SYNOPSIS

  require WWW::Search;
  $search = new WWW::Search('Infoseek::News');
  my $sQuery = WWW::Search::escape_query("plane crash airline disaster");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class implements the Infoseek News search
(specializing Infoseek and WWW::Search).
It handles making and interpreting Infoseek News searches
F<http://www.infoseek.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 
See the value of $TEST_CASES below.

=head1 AUTHOR

C<WWW::Search::Infoseek::News> 
was written by Martin Thurn <MartinThurn@iname.com> 

=cut

#####################################################################

package WWW::Search::Infoseek::News;

require WWW::Search::Infoseek;
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Infoseek Exporter);
$VERSION = '1.09';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Infoseek::News', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_BY_COUNTING, 0);
&test('Infoseek::News', '$MAINTAINER', 'multi', 'pris'.'on* AND esca'.'pe*', \$TEST_GREATER_THAN, 2);
ENDTESTCASES

# private
sub native_setup_search
  {
  my $self = shift;
  $self->{_child_options} = {
                             col => 'NX',
                            };
  # let Infoseek.pm finish up the hard work.
  return $self->SUPER::native_setup_search(@_);
  }

1;
