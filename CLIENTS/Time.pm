#!/usr/local/bin/perl -w

#
# Time.pm
# by Wm. L. Scheding
# Copyright (C) 1996 by USC/ISI
# $Id: Time.pm,v 1.1 1996/10/09 20:21:39 wls Exp $
#
# Copyright (c) 1996 University of Southern California.
# All rights reserved.                                            
#                                                                
# Redistribution and use in source and binary forms are permitted
# provided that the above copyright notice and this paragraph are
# duplicated in all such forms and that any documentation, advertising
# materials, and other materials related to such distribution and use
# acknowledge that the software was developed by the University of
# Southern California, Information Sciences Institute.  The name of the
# University may not be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
# 

package CLIENTS::Time;

=head1 NAME

CLIENTS::Time - class for returning current time

=head1 DESCRIPTION

An interface for returning time, milenium friendly


=head1 SEE ALSO


=head1 METHODS AND FUNCTIONS

=cut

###########################################################

=head2 new

To create a new CLIENT::Time, call
  $now = new CLIENT::Time();

=cut

sub new {
  my ($class) = @_;

  my $self = bless {
  }, $class;
  $self->{now} = ();
  return $self;
}

=head2 now

Return the current time as "01/02/1996 01:02:03" (with spaces)

=cut

sub now {
# make $now.
  my ($now);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $mon += 1; # was zero-relative
  if ($year lt "44") { $year += "2000"; } else { $year += "1900";}
  $now = sprintf("%02d/%02d/%4d %02d:%02d:%02d", $mon, $mday, $year, $hour, $min, $sec);
  return $now;
}

=head2 nows

Return the current time as "01/02/1996_01:02:03" (with_no_spaces)

=cut

sub nows {
# make now without spaces
  my ($nows) = $self->now(); # get now with spaces
  $self->{$nows} =~ tr/ /_/;
  return $self->{$nows};
}

=head2 file_of_the_day_numeric

Return the current time as a daily file name: 19961104"

=cut

sub file_of_the_day_numeric {
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  # be ready for the millennium -- wls
  if ($year lt "44") { $year += "2000"; } else { $year += "1900";}
  my($fod) = sprintf("%04d%02d%02d", $year, $mon + 1, $mday); # YYYYMMDD
  return ($fod);
}

=head2 file_of_the_day

Return the current time as a daily file name: 1996Nov04"

=cut

sub file_of_the_day {
  my(@monthnames) = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
#  my(@daynames) = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat");
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  # be ready for the millennium -- wls
  if ($year lt "44") { $year += "2000"; } else { $year += "1900";}
  my($fod) = sprintf("%04d%03s%02d", $year, $monthnames[$mon], $mday); # YYYYMMMDD
  return ($fod);
}

=head2 file_of_the_time

Return the current time as a daily file name: 1996Nov04173520"

=cut

sub file_of_the_time {
  my(@monthnames) = ("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec");
#  my(@daynames) = ("Sun","Mon","Tue","Wed","Thu","Fri","Sat");
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  # be ready for the millennium -- wls
  if ($year lt "44") { $year += "2000"; } else { $year += "1900";}
  my($f) = sprintf("%04d%03s%02d%02d%02d%02d", $year, $monthnames[$mon], $mday, $hour, $min, $sec); # YYYYMMMDDHHMMSS
  return ($f);
}

1;

