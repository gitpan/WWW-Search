#!/usr/local/bin/perl -w

#
# Web.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: Web.pm,v 1.6 1998/05/28 04:05:53 johnh Exp $

package WWW::Search::Infoseek::Web;

=head1 NAME

WWW::Search::Infoseek::Web - class for Infoseek Web searching


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Infoseek::Web');


=head1 DESCRIPTION

This class implements the Infoseek Web search
(specializing Infoseek and WWW::Search).
It handles making and interpreting Infoseek Web searches
F<http://www.infoseek.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 TESTING

This module adheres to the WWW::Search test harness.  Test cases are:

  'mrfglbqnx NoSuchWord' --> no hits
  'Martin Thurn'         --> 24 hits on one page
  '+Greedo +collector'   --> 63 hits on two pages


=head1 AUTHOR

C<WWW::Search::Infoseek::Web> 
was written by Martin Thurn <mthurn@irnet.rest.tasc.com> 


=cut

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Infoseek Exporter);
use WWW::Search::Infoseek;

# Infoseek.pm does all the work by default!

1;
