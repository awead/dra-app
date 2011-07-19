#!/usr/bin/perl

@dirs = (<$ARGV[0]/*>);

foreach $dir (@dirs) {

	#@parts = split("/", $dir);
	#$folder = pop(@parts);
	
	if (-d $dir) {
		$command = "./marc.pl $dir marc";
		#print $command . "\n";
		`$command`;
	}

}

