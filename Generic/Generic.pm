#!/usr/local/bin/perl -w

#
# Generic.pm
# by Robert Locke
# Copyright (C) 2000 by Infiniteinfo, Inc.
# $Id$
#
# Complete copyright notice follows below.
#


package WWW::Search::Generic;

=head1 NAME

WWW::Search::Generic - class for generic searching.


=head1 SYNOPSIS

    require WWW::Search;
    $search = new WWW::Search('Generic');


=head1 DESCRIPTION

This class implements a Generic search engine that is
configurable via a simple configuration file.

Its current form is more of a proof of concept, sort of a
alpha version 0.1.  Much more work needs to be done
before it can rightfully earn its name.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 OPTIONS

With the exception of the location of the configuration file,
all the options can be specified on the command line, or within
the configuration file.

=over 8

=item search_url=URL

Specifies who to query with the Generic search engine.
There is no default provided, so this is required.

=item search_debug, search_parse_debug, search_ref

Specified at L<WWW::Search>.

=item search_prefix=prefix

Specifies the expression to use before the query string.  For
instance, Amazon's URL queries have the following form:
	http://www.amazon.com/keyword=searchstring&...

The search_prefix in this case would be "keyword=".

=item search_base_url=URL

Specifies a base URL to add to any URLs discovered by
the engine.  For instance, in the case of Amazon.com, all
the generated URLs in a search are relative.  The
search_base_url can be used to prepended a string to each
result to produce an absolute reference.

=item search_next_base_url=URL

Similar to search_base_url, this can be used to create
an absolute reference for the next URL to be fetched by
the engine in the case of multi-page searches.

NOTE: It would be better if the absolute URLs were computed,
rather than forcing the user to specify these options.

=back


=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.


=head1 HOW DOES IT WORK?

The user first specifies an INI-style configuration file
that defines the parameters of the search.  The configuration
file is broken down into 3 major sections:

=item [options]

This defines the engine-level options such as search_url,
search_base_url, etc.  One can also define options to be
used in the generated query string.  For instance, color=black
would append '&color=black' to the final query string URL.

=item [search]

These define the search-level patterns.  This is best explained by
way of example:

    search1=approximate_result_count
    search1_pat=([0-9]+) total matches for

The above two configuration parameters define how to determine
the approximate_result_count for a WWW::Search.  Basically, the
Generic engine will look for the first match of the search
pattern and set "approximate_result_count" to the first matching
sub-pattern (ie, $1).  See below for more complex examples of
search patterns, which are at the heart of the Generic engine.

=item [hit]

These define the hit-level patterns.  These differ from the
search-level patterns in that they are continuously and
exhaustively applied to the result page until no more matches
are left.  For example:

    search1=raw add_url title author format date price
    search1_pat= <<EOT
    (<tr valign=top>
    <td rowspan=2>
    <b>.*</b></td>
    <td colspan=2 valign=top>
    <font size=-1><b>
    <a href=(.*)>(.*)</a></b><br>
    by (.*)\.
    (.*)
    \((.*)\)
    </td>
    </tr>
    <tr valign=top><td.*><font size=-1>
    Our Price:\$(.*)<br>)

The above pattern will be applied to the page, and Generic
will create a new 'hit' (ie, WWW::SearchResult object) for
every match.  The matching sub-patterns (ie, $1, $2, $3, etc.
in Perl nomenclature) will be assigned to raw, add_url,
title, author, etc.

The assignment is done by first checking if the 'hit' object
supports a method by that name (e.g., raw, add_url, title)
and then calling that method.  If the method is not
supported (eg, author, format, price), then the generic _elem
method is called for that particular property.


=head1 SAMPLE CONFIGURATION FILE

Here is a sample configuration file for searching Amazon.com:

[options]
search_base_url=http://www.amazon.com
search_next_base_url=http://www.amazon.com
search_url=http://www.amazon.com/exec/obidos/external-search
search_prefix=keyword=
search_debug=1
index=books
rank=+featuredrank

# For search-level parameters and search patterns.
[search]
search1=approximate_result_count
search1_pat=([0-9]+) total matches for
search2=_next_url
search2_pat=<a href=(.*)><img src="http://g-images.amazon.com/images/G/01/search-browse/button-more-results.gif" width=101 height=20  border=0 alt="More Results"></a>

# For hit-level parameters and search patterns, e.g.,:
# add_url, change_date, description, index_date, normalized_score, raw,
# score, size, title, company, location, source
[hit]
search1=raw add_url title author format date price availability score
search1_pat= <<EOT
(<tr valign=top>
<td rowspan=2>
<b>.*</b></td>
<td colspan=2 valign=top>
<font size=-1><b>
<a href=(.*)>(.*)</a></b><br>
by (.*)\.
(.*)
\((.*)\)
</td>
</tr>
<tr valign=top><td.*><font size=-1>
Our Price:\$(.*)<br>
<br>
</td>
<td.*><font size=-1>
<font color=\#990000>
(.*)<BR>
<!--.* -->
</font>
Average Customer Review:
<IMG SRC="http://images.amazon.com/images/G/01/detail/stars-(.*).gif" border=0 height=12 width=64 ALT=".*">
</td>
</tr>)
EOT


=head1 AUTHOR

C<WWW::Search::Generic> is written and maintained
by Robert Locke, <rlocke@infiniteinfo.com>.


=head1 COPYRIGHT

Copyright (c) 2000 Infiniteinfo, Inc.
All rights reserved.                                            
                                                               
Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all such forms and that any documentation, advertising
materials, and other materials related to such distribution and use
acknowledge that the software was developed by the Infiniteinfo, Inc.
The name of the company may not be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.


=cut
#'

#####################################################################

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
# note that the Generic version number is not synchronized
# with the WWW::Search version number.
$VERSION = '0.1';
#'

use Carp ();
use WWW::Search(generic_option, escape_query);
use Config::IniFiles;
require WWW::SearchResult;

# private
sub native_setup_search
{
    my($self, $native_query, $native_options_ref) = @_;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 0;

    # Read the config file.  Die if we cannot find it.
    my($configfile) = $self->{search_configfile};
    $configfile || die "No configuration file was specified.";
    my($cfg) = Config::IniFiles->new( -file => $configfile ) || die "Could not locate configuration file: $configfile";
    $self->{_cfg} = $cfg;

    if (!defined($self->{_options})) {
	#
	# Load in any options from the configfile.  These can
	# be overwritten from the command line.
	#
	my ($parameter);
	foreach $parameter ($cfg->Parameters("options")) {
	    $self->{_options}{$parameter} = $cfg->val('options', $parameter);
	}
    };

    # Copy in new options.
    # Note that we may be overwriting options from the configuration file.
    my($options_ref) = $self->{_options};
    if (defined($native_options_ref)) {
	foreach (keys %$native_options_ref) {
	    $options_ref->{$_} = $native_options_ref->{$_};
	};
    };

    # Process the options.
    # (Now in sorted order for consistency regarless of hash ordering.)
    my($options) = '';
    foreach (sort keys %$options_ref) {
	# printf STDERR "option: $_ is " . $options_ref->{$_} . "\n";
	# Promote any generic options.
	# This is done in WWW::Search::native_query, so we repeat it here since
	# we may have introduced some generic options in the config file.
	if (generic_option($_)) {
	    $self->{$_} = $options_ref->{$_};
	    next;
	}
	$options .= $_ . '=' . escape_query($options_ref->{$_}) . '&';
    };
    $self->{_debug} = $options_ref->{'search_debug'};
    $self->{_debug} = 2 if ($options_ref->{'search_parse_debug'});
    $self->{_debug} = 0 if (!defined($self->{_debug}));

    # Finally figure out the url.
    $self->{_base_url} = 
	$self->{_next_url} =
	$self->{'search_url'} .
	"?" . $options .
	$self->{'search_prefix'} . $native_query;
    print STDERR $self->{_base_url} . "\n" if ($self->{_debug});
}

# private
sub native_retrieve_some
{
    my ($self) = @_;

    # fast exit if already done
    return undef if (!defined($self->{_next_url}));

    # get some
    print STDERR "WWW::Search::Generic::native_retrieve_some: fetching " . $self->{_next_url} . "\n" if ($self->{_debug});

    my($response) = $self->http_request('GET', $self->{_next_url});
    $self->{response} = $response;
    if (!$response->is_success) {
	return undef;
    };

    #
    # Parse the output.
    # 1) find all the search-level patterns (setting search params)
    # 2) find all the hit-level patterns (setting hit params)
    # 3) the caller can then do whatever (eg, stuff the hits into a database, etc.)
    #
    $self->{_next_url} = undef;
    my ($content) = $response->content();
    my($parameter, $pattern, $i, $field, $value, $match, @fields);
    my($cfg) = $self->{_cfg};
    my($hits_found) = 0;

    foreach $parameter ($cfg->Parameters("search")) {
	if ($parameter !~ /_pat$/) {
	    @fields = split(/\s+/, $cfg->val('search', $parameter));
	} else {
	    $pattern = $cfg->val('search', $parameter);
	    $match = 0;
	    if ($content =~ m#$pattern#) {
		$match = 1;
	    }
	    for $i (0 .. $#fields) {
		$field = $fields[$i];

		if ($match) {
		    $value = ${$i+1};
		    $value = $self->{search_next_base_url} . $value if ($field eq "_next_url");
	        } else {
		    $value = undef;
		}

	        if ($self->can($field)) {
		    $self->$field($value);
		} else {
		    $self->{$field} = $value;
		}
	    }
        }
    }    

    foreach $parameter ($cfg->Parameters("hit")) {
	if ($parameter !~ /_pat$/) {
	    @fields = split(/\s+/, $cfg->val('hit', $parameter));
	} else {
	    $pattern = $cfg->val('hit', $parameter);
	    while ($content =~ s#$pattern##) {
	        my($hit) = new WWW::SearchResult();
	        for $i (0 .. $#fields) {
		    $field = $fields[$i];
		    $value = ${$i+1};
		    $value = $self->{search_base_url} . $value if ($field eq "add_url");
		    print STDERR $field, ": ", $value, "\n" if ($self->{_debug});

		    #
		    # Use the standard method to add the parameter, if it exists.
		    # Otherwise, use the LWP::MemberMixin::_elem method.
		    #
		    if ($hit->can($field)) {
		        $hit->$field($value);
		    } else {
			$hit->_elem($field, $value);
		    }
	        }
	        print STDERR "----------", "\n\n" if ($self->{_debug});
	        $hits_found++;
	        push(@{$self->{cache}}, $hit);
	    }
        }
    }

    print STDERR "Next url: ", $self->{_next_url}, "\n" if ($self->{_debug});
    $self->user_agent_delay if (defined($self->{_next_url}));

    print STDERR "Hits Found: ", $hits_found, "\n" if ($self->{_debug});
    return $hits_found;
}

1;
