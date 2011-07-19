#!/usr/bin/perl

use DRA;
use Path::Class;

my $dir = $ARGV[0];
my $subject = "Marc records";
my $body = "These should be marc records";

my $results = DRA::sendMarc(
    {
    to => "awead\@indiana.edu",
    from => "awead\@indiana.edu",
    subject => $subject,
    body => $body,
    folder => $ARGV[0],
    }
);

if ( $results != 1) {
    print "Some kind of error\n";
}
else {
    print "OK!\n";
}

exit 0;

