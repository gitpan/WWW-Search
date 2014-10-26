# $Id: Empty.pm,v 1.8 2007/05/15 12:04:20 Daddy Exp $

=head1 NAME

WWW::Search::Null::Empty - class for testing WWW::Search clients

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Null::Empty');
  $oSearch->native_query('Makes no difference what you search for...');
  my @aoResults = $oSearch->results;
  # You get no results...
  my $oResponse = $oSearch->response;
  # ...But you get an HTTP::Response object with a code of 200

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

use base 'WWW::Search';
our
$VERSION = do { my @r = (q$Revision: 1.8 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };
our $MAINTAINER = q{Martin Thurn <mthurn@cpan.org>};

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

__END__

