
# $Id: Count.pm,v 1.12 2006/03/12 04:09:23 Daddy Exp $

=head1 NAME

WWW::Search::Null::Count - class for testing WWW::Search clients

=head1 SYNOPSIS

  use WWW::Search;
  my $iCount = 4;
  my $oSearch = new WWW::Search('Null::Count',
                                '_null_count' => $iCount,
                               );
  $oSearch->native_query('Makes no difference what you search for...');
  my @aoResults = $oSearch->results;
  # ...You get $iCount results.

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

use WWW::Search;
use WWW::Search::Result;
use strict;

use vars qw( @ISA $VERSION $MAINTAINER );
@ISA = qw( WWW::Search );
$VERSION = do { my @r = (q$Revision: 1.12 $ =~ /\d+/g); sprintf "%d."."%03d" x $#r, @r };
$MAINTAINER = q{Martin Thurn <mthurn@cpan.org>};

use constant DEBUG_FUNC => 0;

sub _native_setup_search
  {
  my ($self, $native_query, $native_opt) = @_;
  print STDERR " FFF ::Null::Count::_native_setup_search()\n" if (DEBUG_FUNC || $self->{_debug});
  if (! defined $self->{_null_count})
    {
    # print STDERR " +   setting default _null_count to 5\n";
    $self->{_null_count} = 5;
    } # if
  $self->{_allow_empty_query} = 1;
  } # _native_setup_search


sub _native_retrieve_some
  {
  my $self = shift;
  print STDERR " FFF ::Null::Count::_n_r_s()\n" if (DEBUG_FUNC || $self->{_debug});
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
    $oResult->description("description$i");
    $oResult->change_date("yesterday");
    $oResult->index_date("today");
    $oResult->raw(qq{<A HREF="url$i">});
    $oResult->score(100-$i*2);
    $oResult->normalized_score(1000-$i*20);
    $oResult->size($i*2*1024);
    $oResult->source('WWW::Search::Null::Count');
    $oResult->company('Dub Dub Dub Search, Inc.');
    $oResult->location('Ashburn, VA');
    if ($i % 2)
      {
      $oResult->urls("url$i", map { "url$i.$_" } (1..$iCount));
      $oResult->related_urls(map { "url-r$i.$_" } (1..$iCount));
      my @aoTitles = map { "title-r$i.$_" } (1..$iCount);
      $oResult->related_titles(\@aoTitles);
      }
    else
      {
      for my $j (1..$iCount)
        {
        $oResult->add_url(qq{url$i.$j});
        $oResult->add_related_url(qq{url-r$j});
        $oResult->add_related_title(qq{title-r$i});
        } # for $j
      } # else
    push(@{$self->{cache}}, $oResult);
    } # for $i
  return 0;
  } # _native_retrieve_some

1;

__END__

