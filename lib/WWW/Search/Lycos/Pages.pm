# Pages.pm
# by Martin Thurn
# Copyright (C) 1996 by USC/ISI
# $Id: Pages.pm,v 1.1 1999/09/29 20:23:51 mthurn Exp $
#
# Complete copyright notice follows below.

=head1 NAME

WWW::Search::Lycos::Pages - class for Lycos "Web Pages" searching

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Lycos::Pages');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class implements the Lycos Web Pages search
(specializing Lycos and WWW::Search).
It handles making and interpreting Lycos Web Pages searches
F<http://www.lycos.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 TESTING

This module adheres to the WWW::Search test mechanism.
See $TEST_CASES below.

=head1 AUTHOR

C<WWW::Search::Lycos::Pages> 
was written by Martin Thurn <MartinThurn@iname.com> 

=head1 COPYRIGHT

Copyright (c) 1996 University of Southern California.
All rights reserved.                                            
                                                               
Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation, advertising
materials, and other materials related to such distribution and use
acknowledge that the software was developed by the University of
Southern California, Information Sciences Institute.  The name of the
University may not be used to endorse or promote products derived from
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut

#####################################################################

package WWW::Search::Lycos::Pages;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Lycos Exporter);
$VERSION = '2.04';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Lycos::Pages', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Lycos::Pages', '$MAINTAINER', 'one', '+LS'.'AM +repli'.'cation', \$TEST_RANGE, 2,99);
&test('Lycos::Pages', '$MAINTAINER', 'two', 'LS'.'AM', \$TEST_GREATER_THAN, 101);
ENDTESTCASES

use WWW::Search::Lycos;

# let Lycos.pm do all the work!

1;
