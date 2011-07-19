#!/usr/bin/perl

sendEmail ("iuperf\@dlib.indiana.edu, audiopro\@indiana.edu", "audiopro\@indiana.edu", "Jira - IUPerf: test", "test") or die "Unable to use sendmail: $!\n";

sub sendEmail {
	my ($myTo, $myFrom, $mySubject, $myBody) = @_;
	my $sendmail = '/usr/sbin/sendmail';
	open(MAIL, "|$sendmail -oi -t");
	print MAIL "From: $myFrom\n";
	print MAIL "To: $myTo\n";
	print MAIL "Subject: $mySubject\n\n";
	print MAIL "$myBody";
	close(MAIL);
}

