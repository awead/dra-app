#!/usr/bin/perl

use DRA;

#my $age = DRA::checkAge($ARGV[0]);
#
#if ($age > 24) {
#    print "[$age] is greater than 24\n";
#}
#else {
#    print "[$age] is not greater than 24\n";
#}

DRA::setPermissions($ARGV[0]);


exit 0;
