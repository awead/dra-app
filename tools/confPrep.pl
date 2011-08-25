#/usr/bin/perl

my $confFile = $ENV{DRA_HOME} . "/conf/video.conf";

open(FILE, $confFile) or die("Unable to open file");
@data = <FILE>;
close(FILE);
chomp @data;

my @vars;
foreach $line (@data) {

    if ( ($line !~ /^#/) and ($line =~ /=/) ) {
        ($term, $junk) = split(/=/, $line);
        $term =~ s/\s+//g;
        push (@vars, $term);
    }

}

my @sorted = sort @vars;
foreach $var (@sorted) {
    print "\$config->define( \"" . $var . "=s\" );\n";
}



