#!/usr/local/bin/perl -w

# Web.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: Web.pm,v 1.7 1998/08/21 00:03:57 johnh Exp $

package WWW::Search::Infoseek::Web;

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

This module adheres to the WWW::Search test harness.  

  'mrfglbqnx NoSuchWord'       --> no hits
  'Martin Thurn AND Star Wars' --> 11 hits on one page
  'Greedo AND collectible'     --> 38 hits on two pages


=head1 AUTHOR

C<WWW::Search::Infoseek::Web> 
was written by Martin Thurn <MartinThurn@iname.com> 


=cut

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Infoseek Exporter);
$VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use WWW::Search::Infoseek;

# Infoseek.pm does all the work by default!

1;
