

=head1 NAME

WWW::Search::Null::Count - class for testing WWW::Search clients

=head1 SYNOPSIS

=begin example

  require WWW::Search;
  my $iCount = 15;
  my $oSearch = new WWW::Search('Null::Count',
                                '_null_count' => $iCount,
                               );
  $oSearch->native_query('Makes no difference what you search for...');
  my @aoResults = $oSearch->results;
  # ...You get $iCount results.

=end example

=for example_testing
is(scalar(@aoResults), $iCount, 'got the right number of results');
is($oSearch->approximate_result_count, $iCount, 'got the right approx_results');

=head1 DESCRIPTION

This class is a specialization of WWW::Search that returns some hits,
but no error message.  The number of hits returned can be controlled
by adding a '_null_count' hash entry onto the call to
WWW::Search::new().  The default is 5.

This module might be useful for testing a client program without
actually being connected to any particular search engine.

=head1 AUTHOR

Martin Thurn <mthurn@cpan.org>

=cut

package WWW::Search::Null::Count;

use WWW::Search::Result;
use strict;

use vars qw( @ISA );
@ISA = qw( WWW::Search );

sub native_setup_search
  {
  my ($self, $native_query, $native_opt) = @_;
  # print STDERR " + ::Null::Count::native_setup_search()\n";
  if (! defined $self->{_null_count})
    {
    # print STDERR " +   setting default _null_count to 5\n";
    $self->{_null_count} = 5;
    } # if
  } # native_setup_search


sub native_retrieve_some
  {
  my $self = shift;
  # print STDERR " + ::Null::Count::native_retrieve_some()\n";
  my $response = new HTTP::Response(200,
                                    "This is a test of WWW::Search");
  $self->{response} = $response;
  my $iCount = $self->{_null_count};
  # print STDERR " +   iCount is $iCount\n";
  $self->_elem('approx_count', $iCount);
  for my $i (1..$iCount)
    {
    my $oResult = new WWW::Search::Result;
    $oResult->url(qq{url$i});
    $oResult->title(qq{title$i});
    $oResult->description(qq{description$i});
    push(@{$self->{cache}}, $oResult);
    } # for
  return 0;
  } # native_retrieve_some


1;

