#!/usr/local/bin/perl -w

#############################################################
# AdvancedWeb.pm
# by Jim Smyser
# Copyright (c) 1999 by Jim Smyser & USC/ISI
# $Id: AdvancedWeb.pm,v 1.2 1999/07/06 13:44:31 mthurn Exp $
#############################################################


package WWW::Search::AltaVista::AdvancedWeb;

=head1 NAME

WWW::Search::AltaVista::AdvancedWeb - class for advanced Alta Vista web searching

=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('AltaVista::AdvancedWeb');


=head1 DESCRIPTION

Class hack for Advance AltaVista web search mode originally written by  
John Heidemann F<http://www.altavista.com>. 

This hack now allows for AltaVista AdvanceWeb search results
to be sorted and relevant results returned first. Initially, this 
class had skiped the 'r' option which is used by AltaVista to sort
search results for relevancy. Sending advance query using the 
'q' option resulted in random returned search results which made it 
impossible to view best scored results first.  

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 USAGE

Advanced AltaVista searching requires boolean operators: AND, OR, 
AND NOT, NEAR in all uppercase. Phrases require to be enclosed in braces 
( )'s instead of double quotes. Some examples:


(John Heidemann) AND (lsam OR replication) AND NOT (somestupiedword OR thisone)

(lsam OR replication) AND (John Heidemann) AND NOT (somestupiedword OR thisone)
  
Batman and Robin and not Joker

Batman and Robin and not (joker or riddler) 

Comments: For ideal results start your query with the words that
matter most in being returned. This module will take those and apply
them first for sorting purposes.

CASE doesnt matter anymore for the Boolean operators for 'and' will be
uppercased to 'AND'. This is to make constructing complex queries
easier.


=head1 AUTHOR

C<WWW::Search> hack by Jim Smyser, <jsmyser@bigfoot.com>.


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

=head1 VERSION HISTORY

2.01 - Additional query modifiers added for even better results.

2.0 - Minor change to set lowercase Boolean operators to uppercase.

1.9 - First hack version release.

=cut
#'



#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search::AltaVista Exporter);
$VERSION = '2.01';
use WWW::Search::AltaVista;
use WWW::Search(generic_option);


# public
sub version { $VERSION }

# private
sub native_setup_search
{
    my($self, $native_query, $native_options_ref) = @_;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 0;
    # Upper case all lower case Boolean operators. Be nice if
    # I could just uppercase the entire string, but this may
    # have undesirable search side effects. 
    $native_query =~ s/and/AND/g;
    $native_query =~ s/or/OR/g;
    $native_query =~ s/not/NOT/g;
    $native_query =~ s/near/NEAR/g;
    if (!defined($self->{_options})) {
    $self->{_options} = {
        'pg' => 'aq',
        'text' => 'yes',
        'what' => 'web',
        'fmt' => 'd',
        'q' => $native_query,
         'search_url' => 'http://www.altavista.com/cgi-bin/query',
        };
    };
    my($options_ref) = $self->{_options};
    if (defined($native_options_ref)) {
    # Copy in new options.
    foreach (keys %$native_options_ref) {
        $options_ref->{$_} = $native_options_ref->{$_};
    };
    };
    # Process the options.
    my($options) = '';
    foreach (keys %$options_ref) {
    # printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
    next if (generic_option($_));
    $options .= $_ . '=' . $options_ref->{$_} . '&';
    };
    $self->{_debug} = $options_ref->{'search_debug'};
    $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
    $self->{_debug} = 0 if (!defined($self->{_debug}));
    # Finally figure out the url.

    # Here I remove known Boolean operators from the 'r' query option 
    # which is used by AltaVista to sort the results. Finally, clean 
    # up by removing as many of the double ++'s as possibe left behind.
    $native_query =~ s/AND//g;
    $native_query =~ s/OR//g;
    $native_query =~ s/NOT//g;
    $native_query =~ s/NEAR//g;
    $native_query =~ s/"//g;
    $native_query =~ s/%28//g;
    $native_query =~ s/%29//g;
    $native_query =~ s/(\w)\053\053/$1\053/g;
    # strip down the query words
    $native_query =~ s/\W*(\w+\W+\w+\w+\W+\w+).*/$1/;
    $self->{_base_url} = 
    $self->{_next_url} =
    $self->{_options}{'search_url'} .
    "?" . $options .
    "r=" . $native_query;
    print $self->{_base_url} . "\n" if ($self->{_debug});
    # Return to AltaVista for parsing work....
    return $self->SUPER::native_retrieve_some(@_);
}
1;

