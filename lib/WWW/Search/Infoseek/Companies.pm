#!/usr/local/bin/perl -w

# Companies.pm
# by Martin Thurn
# Copyright (C) 1996 by USC/ISI
# $Id: Companies.pm,v 1.3 1998/08/21 00:03:56 johnh Exp $
#
# Complete copyright notice follows below.


package WWW::Search::Infoseek::Companies;

=head1 NAME

WWW::Search::Infoseek::Companies - class for Infoseek Companies searching


=head1 SYNOPSIS
    
  use WWW::Search;
  my $oSearch = new WWW::Search('Infoseek::Companies');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }


=head1 DESCRIPTION

This class implements the Infoseek Companies search
(specializing Infoseek and WWW::Search).
It handles making and interpreting Infoseek Companies searches
F<http://www.infoseek.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 TESTING

This module adheres to the WWW::Search test harness.  Test cases are:

  'mrfglbqnx NoSuchWord' --> no hits
  'Pacific AND travel'   --> 5 hits on one page
  'prison'               --> 30 hits on two pages


=head1 AUTHOR

C<WWW::Search::Infoseek::Companies> 
was written by Martin Thurn <MartinThurn@iname.com> 
based on AltaVista::Web by John Heidemann, <johnh@isi.edu>.


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

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Infoseek Exporter);
$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

use WWW::Search::Infoseek;

# private
sub native_setup_search
  {
  my $self = shift;
  $self->{_child_options} = {
                             col => 'HV',
                            };
  # let Infoseek.pm finish up the hard work.
  return $self->SUPER::native_setup_search(@_);
  }

1;
