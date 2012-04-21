#!/usr/bin/perl -w
#----------------------------------------------------------------------------------------
# marc.pl -- the MARC record module
#
# Adam Wead
# Jacobs School of Music
# Oct. 2008
# $Id: marc.pl,v 1.3 2009/01/27 22:26:05 munsonadmin Exp $
#
#----------------------------------------------------------------------------------------
#
# Input:
#  Argument 1 (required)
#   Folder with files from DRA used in Variations, including all access,
#   preservation, RTF and PDF files.
#
#  Argument 2 (optional)
#   Location you'd like the marc file written. By default, this is the folder
#   of the input
#
#  Argument 3 (optional)
#   Debug level.  Default is 0
#	
# Output:
#   Text file, formatted according to the SirsiDynix flat file marc format.
#   If no second argument is specified, file in the root of the same directory
#   that is the input.
#
# Description:
#  Input a folder from DRA with wav files, parse contents for metadata, output
#  a text file formatted according to the SirsiDynix flat file format into the
#  same directory or directory specified by the second argument.
#
# Fields used from header without any logical comparisons:
#  Marc field number is listed along with it's subfield, ie. |a for subfield a
#   From "info"
#   260c = creationdate
#   490a = name -- this always seems to be "Indiana University Jacobs School
#          of Music" 490v = subject
#   518a = creationdate and keywords--should always be the location
#   810a = name
#   810v = subject
#  From "labl"
#   Track listing is assembled using sample rate data to determine order
#
# Fields used from header with logical comparisons:
#  If the genre field contains either Ensemble, Orchestra, Combo, then:
#   110a = genre
#   245a = name
#   700a = artist
#  Otherwise:
#   100a = artist
#   245a = genre
#
#
# Unused fields from header:
#   'software' => unused at this time
#   'engineers' => unused if no performer info present
#   'copyright' => 'Trustees of Indiana University',
#
# Changelog:
#   trgregg: Retrieved file listing from existing text file instead of search
#   awead:   Changed debug output to a file
#   awead:   added more debug output 2009-11-02
#
#
#-----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
#
# Setup libraries and packages
#
# ----------------------------------------------------------------------------

# We have to have an environment variable telling us where the app is
if ( !$ENV{DRA_HOME} ) {
    die "DRA_HOME not set\n";
}

use lib "$ENV{DRA_HOME}/lib";
use DRA;
#use strict;
#use AppConfig;
#use Path::Class;
#use IO::CaptureOutput qw(capture qxx qxy);
use Carp;
use Audio::Wav;
use Data::Dumper;
use Date::Format;
use Date::Parse;

# Set Data::Dumper options
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Quotekeys = 1;

# Ensemble names that need "Indiana University" added to them
@IUEnsembles = (
 "Brass Choir",
 "Chamber Orchestra",
 "Clarinet Choir",
 "Classical Orchestra",
 "Concert Orchestra",
 "Contemporary Vocal Ensemble",
 "Festival Jazz Orchestra",
 "Festival Orchestra",
 "Jazz Ensemble",
 "Latin American Popular Music Ensemble",
 "New Music Ensemble",
 "Percussion Ensemble",
 "Philharmonic Orchestra",
 "Symphonic Choir",
 "Symphony Orchestra",
 "Wind Ensemble",
);


#-----------------------------------------------------------------------------
#
# Begin Main
#
#-----------------------------------------------------------------------------

# Set debug level and open file
if ($ARGV[2]) {
	$DEBUG = $ARGV[2];
	open(DEBUG, ">debug.txt") || die "Can't open debug file!\n";
}
else {
	$DEBUG = 0;
}

# Check input, remove any trailing slashes
if ($ARGV[0]) {
	
	$path = $ARGV[0];
	$path =~ s/\/$//;

	# Did we get the full path or not?
	if ( $path =~ m/\// ) {
		my @parts = split("/", $path);
		$folder = pop(@parts);
	}
    else {
		$folder = $path;
	}

	print DEBUG "the folder is $folder\n" if ($DEBUG);

}
else {
	die "Need a folder to look in...\n";
}


# Get variationsID from folder path and remove trailing slash if there is one
@pathParts =  split("_", $path);
$varID     =  pop(@pathParts);
$varID     =~ s/\/$//;

# Determine location of _MDSSFileNames.txt
$MDSSFileListingPath 
    = $path 
    . "/access\/logs\/" 
    . $varID 
    . "_MDSSFileNames.txt";

print DEBUG "Path to the MDSS file listing is $MDSSFileListingPath \n" if ($DEBUG);

# Determine location of _MDSSVideoFileNames.txt
$MDSSVideoFileListingPath 
    = $path 
    . "/access\/logs\/" 
    . $varID 
    . "_MDSSVideoFileNames.txt";

print DEBUG "Path to the MDSS video file listing is $MDSSVideoFileListingPath \n" if ($DEBUG);

# Find the access files from which we get the track metadata
$findAccessWAVFiles = "find " . $path . "/access -name " . $varID . "_access\*.wav";
@accessWAVFiles = `$findAccessWAVFiles`;
chomp @accessWAVFiles;

if (!$accessWAVFiles[0]) {
	print DEBUG "No short access file names, looking for long file names  \n" if ($DEBUG);
	$findAccessWAVFiles = "find " . $path . "/access -name jsom_" . $folder . "_access\*.wav";  # jsom_20090116_2030_fh_vaa8915_access1644_001.wav
	@accessWAVFiles = `$findAccessWAVFiles`;
	chomp @accessWAVFiles;}
if (!$accessWAVFiles[0]) {
	die "Error! I didn't find any access files\n";
}

foreach $accessWAVfile (@accessWAVFiles) {
	print DEBUG "access WAV file is $accessWAVfile \n" if ($DEBUG);
}

# Open file to write
if ($ARGV[1]) {
	$outfile = $ARGV[1] . "/" . $varID . "_SD_marc.txt";
} else {
	$outfile = $path . "/" . $varID . "_SD_marc.txt";
}
open (MARC, ">$outfile") or die "Can't open file $outfile for writing.\n";



# Select a wav file to read. In this case, we're just grabbing the first access file... and get the tracks
$infile = $accessWAVFiles[0];
$wavFile = new Audio::Wav;
$wavRead = $wavFile -> read( $infile );
$wavDetl = $wavRead -> details( );
$info = $wavDetl -> {'info'};
$labl = $wavDetl -> {'labl'};
$cue = $wavDetl -> {'cue'};
print DEBUG "Dumping all data from access file $infile :\n" . Dumper($wavDetl) if ($DEBUG > 1);
print DEBUG "Dumping labl data from access file $infile :\n" . Dumper($labl) if ($DEBUG);
print DEBUG "Dumping cue data from access file $infile :\n" . Dumper($cue) if ($DEBUG);
@tracks = &getTracks($labl, $cue);



# Get tracks from other files, if needed
print DEBUG (scalar(@accessWAVFiles)) . " total files found\n" if ($DEBUG);
if ( (scalar(@accessWAVFiles)) > 1 ) {
	
	print DEBUG "More files found... getting track information\n" if ($DEBUG);
	$next = 1;
	while ( $next < (scalar(@accessWAVFiles))) {
		$next_infile = $accessWAVFiles[$next];
		print DEBUG "getting track information for " . $next_infile . "\n" if ($DEBUG);
		
		my $next_wavFile = new Audio::Wav;
		my $next_wavRead = $next_wavFile -> read( $next_infile );
		my $next_wavDetl = $next_wavRead -> details( );
		my $next_labl = $next_wavDetl -> {'labl'};
		my $next_cue = $next_wavDetl -> {'cue'};
		print DEBUG "Dumping all data for access file $next_infile :\n" . Dumper($next_wavDetl) if ($DEBUG);
		print DEBUG "Dumping labl data for access file $next_infile :\n" . Dumper($next_labl) if ($DEBUG);
		print DEBUG "Dumping cue data for access file $next_infile :\n" . Dumper($next_cue) if ($DEBUG);
		@next_tracks = &getTracks($next_labl, $next_cue);
		push(@tracks, @next_tracks);
		$next++;
	}

}



# Create contents listing
$contentsLine = diacritFix( join(" ; ", @tracks) );

if ($DEBUG) {
	print DEBUG "Printing a human-readable listing of the tracks:\n";
	my $trackNumber = 1;
	foreach $HRtrack (@tracks) {
		print DEBUG "       Track " . $trackNumber . " -- " . $HRtrack . "\n";
		$trackNumber++;
	}
}



# Format time and date fields
$dateTime = str2time($info->{'creationdate'});

if ($dateTime) {
	
	print DEBUG "dateTime variable is $dateTime\n" if ($DEBUG);
	$year = time2str("%Y", $dateTime);
	$fullDate = time2str("%B %e, %Y at %l %p", $dateTime);
	$fullDate =~ s/\s\s/ /g;
	$sixDigitDate = time2str("%y%m%d", $dateTime);

} else {
	
	die "marc.pl error: Missing or malformed date in wave file header. Aborting...\n";

}

# Read file content lines of the _MDSSFilesNames.txt file to get the information for the record
open (READMDSS, $MDSSFileListingPath) || (die "Can't open file $MDSSFileListingPath\n");
@MDSSAllFiles = <READMDSS>;
close (READMDSS);

# Clean up text and parse out access and presevation file information
$MDSSAllFilesLine = join ("", @MDSSAllFiles);
chomp $MDSSAllFilesLine;
$MDSSAllFilesLine =~ s/\r//g;
print DEBUG "MDSSAllFilesLine is -- " . $MDSSAllFilesLine . "--\n" if ($DEBUG);
@MDSSAllFilesParts = split(/\n{2,}/, $MDSSAllFilesLine);
$MDSSPresFiles = $MDSSAllFilesParts[0];
$MDSSPresFiles =~ s/\n\s/\n/g;
print DEBUG "MDSSPresFiles are --" . $MDSSPresFiles . "--\n" if $DEBUG;  
$MDSSAccessFiles = $MDSSAllFilesParts[1];
$MDSSAccessFiles =~ s/\n\s/\n/g;
print DEBUG "MDSSAcessFiles are --" . $MDSSAccessFiles . "--\n" if $DEBUG;  

# Check for video file
if (-e $MDSSVideoFileListingPath) {
    open (READVIDEOMDSS, $MDSSVideoFileListingPath) 
        || (die "Can't open file $MDSSVideoFileListingPath\n");
    @MDSSVideoFiles = <READVIDEOMDSS>;
    close (READVIDEOMDSS);

    # Clean up
    $MDSSVideoFilesLine = join ("", @MDSSVideoFiles);
    chomp $MDSSVideoFilesLine;
    $MDSSVideoFilesLine =~ s/\r//g;
    if ($DEBUG) {
        print DEBUG "Video files line is --" . $MDSSVideoFilesLine . "--\n";
    }
}


# Create the 008 field
# 
# The first part is created using data from the wave header
# Bytes 00-05 are the current date in yymmdd format
# Byte 06 will be 's'
# Bytes 07-10 will be the performance's year (yyyy)
# Bytes 11-14 will be four spaces '    '
# Bytes 15-17 will be xx and a space 'xx '
# 
# From there it starts getting complicated, but these are the basic filler values if it is sufficient to leave the coding until a real person deals with it:
# 
# Bytes 18-19 can be two pipe characters '||'
# Byte 20 will be 'n'
# Byte 21 can be a space ' '
# Byte 22 can be a space ' '
# Byte 23 will be 's'
# Bytes 24-29 can be six spaces '      '
# Bytes 30-31 will be two spaces '  '
# Byte 32 should be a space ' '
# Byte 33 can be a space ' '
# Byte 34 should be a space ' '
# Bytes 35-37 can be three spaces '   '
# Byte 38 should be a space ' '
# Byte 39 should be a 'd'

$eightFieldLine = 
  $sixDigitDate . 
  "s" . 
  $year . 
  "    " . 
  "xx " . 
  "||" .
  "n" . 
  " " . 
  " " . 
  "s" . 
  "      " . 
  "  " .
  " " . 
  " " .
  "   " .
  " " .
  "d";

# Determine the contents of our 100, 110, 245 and 700 fields, based on the metadata in genre
#  Case 1:        a university ensemble
#  Determination: the words "ensemble" or "orchestra" or "choir" are found in the genre field
#  Result:        artist goes in to the 70o field, genre in the 110 and 245 is constructed
#
#  Case 2:        everything else...
#
# Print out the record

# Header info that's the same for either case
print MARC "*** DOCUMENT BOUNDARY ***\n";
print MARC "FORM=SOUND\n";
print MARC ".008." . " " . "|a" . $eightFieldLine . "\n";

# Case 1 records
if ( $info->{'genre'} =~ m/orchestra|ensemble|choir|singers|trio|quartet|quintet|institute|concentus/i ) {

	# Some names need to have "Indiana University" added to them
	$IUnames = join("|", @IUEnsembles);
	my $query = qr/^$IUnames$/i;
		
	if ( $info->{'genre'} =~ $query ) {
		$prep_name = "Indiana University " . $info->{'genre'};
	} elsif ( $info->{'genre'} =~ m/^University/ ) {
		$prep_name = "Indiana " . $info->{'genre'};
	} else {
		$prep_name = $info->{'genre'};
	}

	$name = diacritFix( $prep_name );

	# Case 1
	print MARC ".110." . " 2 " . "|a" . $name . "\n";
	print MARC ".245." . " 00" . "|a [Program, " . $info->{'subject'} . " ]|h[electronic resource]\n";
	print MARC ".260." . "   " . "|a[Bloomington, Ind. :|bWilliam and Gayle Cook Music Library,|c" . $year . "]\n";
	print MARC ".490." . " 1 " . "|aProgram / Indiana University Jacobs School of Music ;|v" . $info->{'subject'}  . "\n";
	print MARC ".500." . "   " . "|aAUTOMATED PRELIMINARY CATALOG RECORD.\n";
	print MARC ".500." . "   " . "|aStreaming audio.\n";
	print MARC ".538." . "   " . "|aMode of access: Available to authorized users of the Variations system.\n";
	print MARC ".500." . "   " . "|aTitle from WAV file header.\n";
	print MARC ".511." . "   " . "|a" . $name . " ; " . $info->{'artist'} . "\n";
	print MARC ".518." . "   " . "|aRecorded on " . $fullDate . ", " . $info->{'keywords'} . ", Indiana University, Bloomington.\n";
	print MARC ".505." . " 0 " . "|a" . $contentsLine . "\n";
	print MARC ".500." . "   " . "|a" . $MDSSPresFiles . "\n";
	print MARC ".500." . "   " . "|a" . $MDSSAccessFiles . "\n";
	print MARC ".500." . "   " . "|a" . $MDSSVideoFilesLine . "\n" if $MDSSVideoFilesLine;
	print MARC ".700." . "   " . "|a" . diacritFix( $info->{'artist'} ) . "\n";
	print MARC ".810." . " 2 " . "|aIndiana University Jacobs School of Music.|tProgram ;|v" . $info->{'subject'} . "\n";
	print MARC ".856." 
        . " 40" 
        . "|aBloomington|xhttp://purl.dlib.indiana.edu/iudl/variations/sound/" 
        . $varID 
        . "|xAvailable to authorized users of the Variations System"
        . "|uOnline copy in process. Not yet available.\n"
        ;

# Case 2 records
} else {

	# Determine 245 line
	my $offset = &firstWord($info->{'genre'});

	# Case 2
	print MARC ".100." . " 1 " .    "|a" . diacritFix( $info->{'artist'} ) . "\n";
	print MARC ".245." . $offset .  "|a" . diacritFix( $info->{'genre'} ) . "|h[electronic resource]\n";
	print MARC ".260." . "   " .    "|a[Bloomington, Ind. :|bWilliam and Gayle Cook Music Library,|c" . $year . "]\n";
	print MARC ".490." . " 1 " .    "|aProgram / Indiana University Jacobs School of Music ;|v" . $info->{'subject'}  . "\n";
	print MARC ".500." . "   " .    "|aAUTOMATED PRELIMINARY CATALOG RECORD.\n";
	print MARC ".500." . "   " .    "|aStreaming audio.\n";
	print MARC ".538." . "   " .    "|aMode of access: Available to authorized users of the Variations system.\n";
	print MARC ".500." . "   " .    "|aTitle from wave file header.\n";
	print MARC ".518." . "   " .    "|aRecorded on " . $fullDate . ", " . $info->{'keywords'} . ", Indiana University, Bloomington.\n";
	print MARC ".505." . " 0 " .    "|a" . $contentsLine . "\n";
	print MARC ".500." . "   " .    "|a" . $MDSSPresFiles . "\n";
	print MARC ".500." . "   " .    "|a" . $MDSSAccessFiles . "\n";
	print MARC ".500." . "   " . "|a" . $MDSSVideoFilesLine . "\n" if $MDSSVideoFilesLine;
	print MARC ".810." . " 2 " .    "|aIndiana University Jacobs School of Music.|tProgram ;|v" . $info->{'subject'} . "\n";
	print MARC ".856." 
        . " 40" 
        . "|aBloomington|xhttp://purl.dlib.indiana.edu/iudl/variations/sound/" 
        . $varID 
        . "|xAvailable to authorized users of the Variations System"
        . "|uOnline copy in process. Not yet available.\n"
        ;

}

# Footer info for all records
print MARC ".949.   |tNONCIRC|l_MUVARIA|mB-MUSIC|xIUPERF|zSTRAUDIO\n";

# Close file
close (MARC);
close (DEBUG) if ($DEBUG);


#
# end Main
#



#---------------------------------------------------------------------------------------
#
# Subroutines
#
#---------------------------------------------------------------------------------------



#---------------------------------------------------------------------------------------
# Name:    getTracks
# Use:     Return correctly ordered listing of tracks from wave header data
# Input:   Data objects from "labl" field and "cue" fields of wave header
# Output:  Array of track names, sorted in order
# Globals: Uses global $DEBUG variable for printing extra info
#---------------------------------------------------------------------------------------
sub getTracks {

	my ($names, $cues)  = @_;
	my @array1 = sort keys %$names;
	my @array2 = sort keys %$cues;
	my %tracks = ();
	my @samples = ();
	my @orderedSamples = ();
	my @output = ();

	if ( @array1 == @array2 ) {

		# Get sample data and names
		foreach my $element (@array2) {
			
			my $sampleNumber = $$cues{$element}{'position'};
			my $name = $$names{$element};
			print DEBUG "getTracks, Track name " . $name  ." is at sample number " . $sampleNumber . "\n" if ($DEBUG);
			$tracks{$sampleNumber} = $name;

		}

		# Sort samples in numerical order
		@samples = keys %tracks;
		@orderedSamples = sort { $a <=> $b } @samples;

		# Assemble track according to sample order
		foreach my $sample (@orderedSamples) {
			print DEBUG "getTracks, sample # " . $sample . " is " . $tracks{$sample} . "\n" if ($DEBUG);
			push(@output, $tracks{$sample});
		}

		my $counter = 0;
		while ( $counter < @output) {
			print DEBUG "getTracks, Index $counter is $output[$counter]\n" if $DEBUG;
			$counter++;
		}

		return @output;
	
	} else {

		print DEBUG "getTracks, There was an error determinging track order...dumping output:\n" if ($DEBUG);
		foreach my $elem1 (@array1) {
			print DEBUG "getTracks, array of label data: index $elem1 , value $array1[$elem1] \n" if ($DEBUG);
		}
		foreach my $elem2 (@array1) {
			print DEBUG "getTracks, array of cue data: index $elem2 , value $array2[$elem2] \n" if ($DEBUG);
		}
		die "There was an error determinig track order";

	}

}



#---------------------------------------------------------------------------------------
# Name:    firstWord
# Use:     Return the numerical offset to the first significant word in a string
# Input:   String of text
# Output:  Number
# Globals: Uses global $DEBUG variable for printing extra info
#---------------------------------------------------------------------------------------
sub firstWord {

	my $name = shift;
	my $found = 0;
	my $string = ();
	my %words = (
		"The" => 4,
		"An"  => 3,
		"A"   => 2,
		"Of"  => 3,
		"La"  => 3,
		"Il"  => 3,
		"Die" => 4
	);

	foreach my $word ( keys %words ) {

		print DEBUG "firstWord, checking for word ( $word ) in string ( $name ) \n" if $DEBUG;

		if ( $name =~ m/^$word\s/i ) {
			$found = $words{$word};
		}

	}
					
	if ($found) {
		$string = " " . $found . " ";
	} else {
		$string = " 00";
	}

	return $string;

}


#---------------------------------------------------------------------------------------
# Name:    diacritFix
# Use:     Fixes diacritics using simple search and replace methods (taken from Spencer at LIT)
# Input:   String of text
# Output:  Converted string of text
# Globals: Uses global $DEBUG variable for printing extra info
#---------------------------------------------------------------------------------------

sub diacritFix {

	my $line = shift;
	my $newline = ();
	
	print DEBUG "dicritFix: $line \n" if ($DEBUG);

	foreach (my $i = 0; $i <= length($line); $i++) {

		my $char = substr($line,$i,1);

		print DEBUG "diacritFix, $char\n" if ($DEBUG);
		
		if ($char =~ /\xF0/) { $char =~ s/\xF0/\xBA/; } #<lowercase_eth>
		elsif ($char =~ /\xE7/) { $char =~ s/\xE7/\xF0\x63/; } #<c_with_cedilla>
		elsif ($char =~ /\xC7/) { $char =~ s/\xC7/\xF0\x43/; } #<capital_c_with_cedilla>
		
		elsif ($char =~ /\xE2/) { $char =~ s/\xE2/\xE3\x61/; } #<a_with_circumflex>
		elsif ($char =~ /\xE1/) { $char =~ s/\xE1/\xE2\x61/; } #<a_with_acute>
		elsif ($char =~ /\xE8/) { $char =~ s/\xE8/\xE1\x65/; } #<e_with_grave>
		elsif ($char =~ /\xE4/) { $char =~ s/\xE4/\xE8\x61/; } #<a_with_umlaut>
		elsif ($char =~ /\xE3/) { $char =~ s/\xE3/\xE4\x61/; } #<a_with_tilde>
		elsif ($char =~ /\xEA/) { $char =~ s/\xEA/\xE3\x65/; } #<e_with_circumflex>
		elsif ($char =~ /\xE5/) { $char =~ s/\xE5/\xEA\x61/; } #<a_with_circle_above_angstrom>
		elsif ($char =~ /\xC5/) { $char =~ s/\xC5/\xEA\x41/; } #<capital_a_with_circle_above_angstrom>
		
		elsif ($char =~ /\xFF/) { $char =~ s/\xFF/\xE8\x79/; } #<y_with_umlaut>
		elsif ($char =~ /\xFC/) { $char =~ s/\xFC/\xE8\x75/; } #<u_with_umlaut>
		elsif ($char =~ /\xF6/) { $char =~ s/\xF6/\xE8\x6F/; } #<o_with_umlaut>
		elsif ($char =~ /\xEF/) { $char =~ s/\xEF/\xE8\x69/; } #<i_with_umlaut>
		elsif ($char =~ /\xEB/) { $char =~ s/\xEB/\xE8\x65/; } #<e_with_umlaut>
		elsif ($char =~ /\xDC/) { $char =~ s/\xDC/\xE8\x55/; } #<latin_capital_letter_u_with_umlaut>
		elsif ($char =~ /\xD6/) { $char =~ s/\xD6/\xE8\x4F/; } #<latin_capital_letter_o_with_umlaut>
		elsif ($char =~ /\xCF/) { $char =~ s/\xCF/\xE8\x49/; } #<latin_capital_letter_i_with_umlaut>
		elsif ($char =~ /\xCB/) { $char =~ s/\xCB/\xE8\x45/; } #<latin_capital_letter_e_with_umlaut>
		elsif ($char =~ /\xC4/) { $char =~ s/\xC4/\xE8\x41/; } #<latin_capital_letter_a_with_umlaut>
		
		elsif ($char =~ /\xF5/) { $char =~ s/\xF5/\xE4\x6F/; } #<o_with_tilde>
		elsif ($char =~ /\xF1/) { $char =~ s/\xF1/\xE4\x6E/; } #<n_with_tilde>
		elsif ($char =~ /\xD5/) { $char =~ s/\xD5/\xE4\x4F/; } #<latin_capital_letter_o_with_tilde>
		elsif ($char =~ /\xD1/) { $char =~ s/\xD1/\xE4\x4E/; } #<latin_capital_letter_n_with_tilde>
		elsif ($char =~ /\xC3/) { $char =~ s/\xC3/\xE4\x41/; } #<latin_capital_letter_a_with_tilde>
		
		elsif ($char =~ /\xFB/) { $char =~ s/\xFB/\xE3\x75/; } #<u_with_circumflex>
		elsif ($char =~ /\xF4/) { $char =~ s/\xF4/\xE3\x6F/; } #<o_with_circumflex>
		elsif ($char =~ /\xEE/) { $char =~ s/\xEE/\xE3\x69/; } #<i_with_circumflex>
		elsif ($char =~ /\xDB/) { $char =~ s/\xDB/\xE3\x55/; } #<latin_capital_letter_u_with_circumflex>
		elsif ($char =~ /\xD4/) { $char =~ s/\xD4/\xE3\x4F/; } #<latin_capital_letter_o_with_circumflex>
		elsif ($char =~ /\xCE/) { $char =~ s/\xCE/\xE3\x49/; } #<latin_capital_letter_i_with_circumflex>
		elsif ($char =~ /\xCA/) { $char =~ s/\xCA/\xE3\x45/; } #<latin_capital_letter_e_with_circumflex>
		elsif ($char =~ /\xC2/) { $char =~ s/\xC2/\xE3\x41/; } #<latin_capital_letter_a_with_circumflex>
		
		elsif ($char =~ /\xFD/) { $char =~ s/\xFD/\xE2\x79/; } #<y_with_acute>
		elsif ($char =~ /\xFA/) { $char =~ s/\xFA/\xE2\x75/; } #<u_with_acute>
		elsif ($char =~ /\xF3/) { $char =~ s/\xF3/\xE2\x6F/; } #<o_with_acute>
		elsif ($char =~ /\xED/) { $char =~ s/\xED/\xE2\x69/; } #<i_with_acute>
		elsif ($char =~ /\xE9/) { $char =~ s/\xE9/\xE2\x65/; } #<e_with_acute>
		elsif ($char =~ /\xDD/) { $char =~ s/\xDD/\xE2\x59/; } #<latin_capital_letter_y_with_acute>
		elsif ($char =~ /\xDA/) { $char =~ s/\xDA/\xE2\x55/; } #<latin_capital_letter_u_with_acute>
		elsif ($char =~ /\xD3/) { $char =~ s/\xD3/\xE2\x4F/; } #<latin_capital_letter_o_with_acute>
		elsif ($char =~ /\xCD/) { $char =~ s/\xCD/\xE2\x49/; } #<latin_capital_letter_i_with_acute>
		elsif ($char =~ /\xC9/) { $char =~ s/\xC9/\xE2\x45/; } #<latin_capital_letter_e_with_acute>
		elsif ($char =~ /\xC1/) { $char =~ s/\xC1/\xE2\x41/; } #<latin_capital_letter_a_with_acute>
		elsif ($char =~ /\xF9/) { $char =~ s/\xF9/\xE1\x75/; } #<u_with_grave>
		elsif ($char =~ /\xF2/) { $char =~ s/\xF2/\xE1\x6F/; } #<o_with_grave>
		elsif ($char =~ /\xEC/) { $char =~ s/\xEC/\xE1\x69/; } #<i_with_grave>
		elsif ($char =~ /\xE0/) { $char =~ s/\xE0/\xE1\x61/; } #<a_with_grave>
		elsif ($char =~ /\xD9/) { $char =~ s/\xD9/\xE1\x55/; } #<latin_capital_letter_u_with_grave>
		elsif ($char =~ /\xD2/) { $char =~ s/\xD2/\xE1\x4F/; } #<latin_capital_letter_o_with_grave>
		elsif ($char =~ /\xCC/) { $char =~ s/\xCC/\xE1\x49/; } #<latin_capital_letter_i_with_grave>
		elsif ($char =~ /\xC8/) { $char =~ s/\xC8/\xE1\x45/; } #<latin_capital_letter_e_with_grave>
		elsif ($char =~ /\xC0/) { $char =~ s/\xC0/\xE1\x41/; } #<latin_capital_letter_a_with_grave>
		elsif ($char =~ /\xDF/) { $char =~ s/\xDF/\xC7/; } #<eszett>
		elsif ($char =~ /\xA1/) { $char =~ s/\xA1/\xC6/; } #<inverted_exclamation_mark>
		elsif ($char =~ /\xBF/) { $char =~ s/\xBF/\xC5/; } #<inverted_question_mark>
		elsif ($char =~ /\xA9/) { $char =~ s/\xA9/\xC3/; } #<copyright_sign>
		elsif ($char =~ /\xB0/) { $char =~ s/\xB0/\xC0/; } #<degree_sign>
		elsif ($char =~ /\xA3/) { $char =~ s/\xA3/\xB9/; } #<british_pound>
		elsif ($char =~ /\xE6/) { $char =~ s/\xE6/\xB5/; } #<lowercase_digraph_ae>
		elsif ($char =~ /\xFE/) { $char =~ s/\xFE/\xB4/; } #<lowercase_icelandic_thorn>
		elsif ($char =~ /\xF8/) { $char =~ s/\xF8/\xB2/; } #<lowercase_scandinavian_o>
		elsif ($char =~ /\xB1/) { $char =~ s/\xB1/\xAB/; } #<plus_or_minus>
		elsif ($char =~ /\xAE/) { $char =~ s/\xAE/\xAA/; } #<patent_mark>
		elsif ($char =~ /\xB7/) { $char =~ s/\xB7/\xA8/; } #<middle_dot>
		elsif ($char =~ /\xC6/) { $char =~ s/\xC6/\xA5/; } #<uppercase_digraph_ae>
		elsif ($char =~ /\xDE/) { $char =~ s/\xDE/\xA4/; } #<uppercase_icelandic_thorn>
		elsif ($char =~ /\xD0/) { $char =~ s/\xD0/\xA3/; } #<uppercase_d_with_crossbar>
		elsif ($char =~ /\xD8/) { $char =~ s/\xD8/\xA2/; } #<uppercase_scandinavian_o>
		
		elsif ($char =~ /\x96/) { $char =~ s/\x96/\x2D/; } #smart hyphen
		elsif ($char =~ /\x85/) { $char =~ s/\x85/\x2E\x2E\x2E/; } #smart elipsis
		elsif ($char =~ /\x92/) { $char =~ s/\x92/\x27/; } #smart close quote
		
		elsif ($char =~ /[\x80-\xFF]/) { print "ERROR: $char \n"; }
		
		$newline .= $char;
	}

	print DEBUG "diacritFix, $newline\n" if ($DEBUG);
	return $newline;

}


