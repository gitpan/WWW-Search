# $Id: Empty.pm,v 1.4 2004/05/24 12:20:04 Daddy Exp $

=head1 NAME

WWW::Search::Null::Empty - class for testing WWW::Search clients

=head1 SYNOPSIS

=begin example

  require WWW::Search;
  my $oSearch = new WWW::Search('Null::Empty');
  $oSearch->native_query('Makes no difference what you search for...');
  my @aoResults = $oSearch->results;
  # You get no results...
  my $oResponse = $oSearch->response;
  # ...But you get an HTTP::Response object with a code of 200

=end example

=for example_testing
ok($oResponse->is_success, 'did not get a 500 HTTP::Response');
is(scalar(@aoResults), 0, 'got some results');

=head1 DESCRIPTION

This class is a specialization of WWW::Search that returns no hits,
but no error message.

This module might be useful for testing a client program without
actually being connected to any particular search engine.

=head1 AUTHOR

Martin Thurn <mthurn@cpan.org>

=cut

package WWW::Search::Null::Empty;

use strict;

use vars qw( @ISA $VERSION );
@ISA = qw( WWW::Search );
$VERSION = do { my @r = (q$Revision: 1.4 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };

sub _native_setup_search
  {
  my($self, $native_query, $native_opt) = @_;
  } # native_setup_search


sub _native_retrieve_some
  {
  my $self = shift;
  my $response = new HTTP::Response(200,
                                    "This is a test of WWW::Search");
  $self->{response} = $response;
  return 0;
  } # native_retrieve_some


1;

