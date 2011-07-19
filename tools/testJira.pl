#!/usr/bin/perl

use DRA;
use Path::Class;

my $dir = $ARGV[0];

my $subject = DRA::jiraSubject( $dir );
my $body    = DRA::jiraMessage( $dir );

print $subject . "\n\n";
print $body . "\n\n";

DRA::sendEmail(
    {
    to => "awead\@indiana.edu",
    from => "awead\@indiana.edu",
    subject => $subject,
    body => $body,
    }
);


exit 0;

