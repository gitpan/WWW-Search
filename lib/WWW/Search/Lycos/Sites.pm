# Sites.pm
# by Martin Thurn
# Copyright (C) 1996 by USC/ISI
# $Id: Sites.pm,v 1.6 1999/12/22 20:45:43 mthurn Exp $
#
# Complete copyright notice follows below.

=head1 NAME

WWW::Search::Lycos::Sites - class for Lycos categorized "Web Sites" searching

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Lycos::Sites');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class implements the Lycos Web Sites search
(specializing Lycos and WWW::Search).
It handles making and interpreting Lycos Web Sites searches
F<http://www.lycos.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 NOTES

The default search mode is "any" of the query terms.  If you want to
search for "ALL" of the query terms, add {'matchmode' => 'and'} as the
second argument to native_query().  More advanced query modes can be
added upon request; please contact the author.

=head1 TESTING

This module adheres to the WWW::Search test mechanism.
See $TEST_CASES below.

=head1 AUTHOR

C<WWW::Search::Lycos::Sites> 
was written by Martin Thurn <MartinThurn@iname.com> 

=head1 VERSION HISTORY

If it''s not listed here, then it wasn''t a meaningful nor released revision.

=head2 2.07, 1999-12-22

pod update

=head2 2.06, 1999-12-10

handle missing 'next' link

=head2 2.05, 1999-12-03

new search parameters and new search url

=head2 2.04, 1999-10-10

First public release (coincided with WWW::Search 2.04).

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

package WWW::Search::Lycos::Sites;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Lycos Exporter);
$VERSION = '2.07';

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Lycos::Sites', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Lycos::Sites', '$MAINTAINER', 'one', 'fabri'.'kal', \$TEST_RANGE, 2,9);
&test('Lycos::Sites', '$MAINTAINER', 'two', 'polemi'.'st', \$TEST_GREATER_THAN, 11);
ENDTESTCASES

use WWW::Search::Lycos;

# private
sub native_setup_search
  {
  my $self = shift;
  # Lycos returns 10 hpp no matter what:
  $self->{'_hits_per_page'} = 10;  
  # By using _options, we totally replace the settings of the parent
  # (if we just want to add to the parent, we can use _child_options)
  $self->{'search_base_url'} = 'http://www.lycos.com';
  $self->{_options} = {
                       first => 1,
                       # page => 1,
                       search_url => $self->{'search_base_url'} .'/srch/more.html',
                       type => 'websites',
                      };
  # let Lycos.pm finish up the hard work.
  return $self->SUPER::native_setup_search(@_);
  }

1;

__END__

NEW FORMAT 1999-12-01:

full url: http://www.lycos.com/srch/more.html?lpv=1&type=websites&loc=mlink_w&l=12&y=89724&c=2111&o=27&s=91874&pn=&qc=Y&page=1&query=star+wars&first=1

minimal url: http://www.lycos.com/srch/more.html?type=websites&page=1&query=star+wars&first=1
