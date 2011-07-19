#!/usr/bin/perl
# We have to have an environment variable telling us where the app is
if ( !$ENV{DRA_HOME} ) {
    die "DRA_HOME not set\n";
}

use lib "$ENV{DRA_HOME}/lib";
use DRA;

DRA::setFolderLabel($ARGV[0], $ARGV[1]);

