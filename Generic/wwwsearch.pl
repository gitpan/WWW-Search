#!/usr/local/bin/perl

use WWW::Search;
my $oSearch = new WWW::Search('Generic');
my $sQuery = WWW::Search::escape_query("semiconductor");
$oSearch->native_query($sQuery,
		       {
			   'search_configfile' => 'amazon.ini'
			   });

while (my $res = $oSearch->next_result()) {
    print $res->url . "\n\t" . $res->{title} . "\n\t" . $res->{author}
    . "\n\t" . $res->{format} . "\n\t" . $res->{date} . "\n\t" . $res->{price}
    . "\n\t" . $res->{availability} . "\n\t" . $res->{score} . "\n\n";
}
