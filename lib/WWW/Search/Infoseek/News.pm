#!/usr/local/bin/perl -w

#
# News.pm
# Copyright (c) 1998 by Martin Thurn
# $Id: News.pm,v 1.7 1998/05/28 04:05:52 johnh Exp $


package WWW::Search::Infoseek::News;

=head1 NAME

WWW::Search::Infoseek::News - class for Infoseek News searching


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Infoseek::News');


=head1 DESCRIPTION

This class implements the Infoseek News search
(specializing Infoseek and WWW::Search).
It handles making and interpreting Infoseek News searches
F<http://www.infoseek.com>.

This class exports no public interface; all interaction should
be done through WWW::Search objects.


=head1 TESTING

This module adheres to the WWW::Search test harness.  Test cases are:

  'mrfglbqnx NoSuchWord' --> no hits
  'Star Wars'            --> 13 hits on one page
  'Hawaii'               --> 54 hits on two pages


=head1 AUTHOR

C<WWW::Search::Infoseek::News> 
was written by Martin Thurn <mthurn@irnet.rest.tasc.com> 


=cut

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::Infoseek Exporter);
use WWW::Search::Infoseek;

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
