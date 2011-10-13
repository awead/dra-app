#!/usr/bin/perl
# ----------------------------------------------------------------------------
# Package: Department of Recordings Arts
# Desc:    Package of perl subroutines and code used by the Department of
#          Recording Arts for their audio transfer and archiving applicaiton
#
# Travis Gregg, Adam Wead
# Jacobs School of Music
# Indiana University
# ----------------------------------------------------------------------------

package DRA;
use Carp;
use Path::Class;

# -------------------------------------------------------------------------
# Name:    getCurrentTime
# Desc:    Returns current time in a given format with a hard return
# Inputs:  none
# Outputs: formatted time string
# -------------------------------------------------------------------------
sub getCurrentTime {

    use POSIX qw(strftime);
    my $currentTime = strftime "%a %b %e %H:%M:%S %Y", localtime;
    return $currentTime;

} # end getCurrentTime


# -------------------------------------------------------------------------
# Name:    logger
# Desc:    General file logger that writes a message to a file
# Inputs:  message, file
# Outputs: none
# -------------------------------------------------------------------------
sub logger {

    my ($message, $file) = @_;
        
    open (FILE, ">>$file") or die "Can't open file = $file !\n";
    print FILE DRA::getCurrentTime . " - " . $message . "\n";
    close FILE;
    return 0;
    
}


# -------------------------------------------------------------------------
# Name:    writer
# Desc:    General file write that writes to file, but never appends
#          Note: this is different than the logger subroutine which appends
#          to the file if it already exists.
# Inputs:  message, file
# Outputs: none
# -------------------------------------------------------------------------
sub writer {

    my ($message, $file) = @_;

    open (FILE, ">$file") or die "Can't open file = $file !\n";
    print FILE $message;
    close FILE;
    return 0;
    
}


# -------------------------------------------------------------------------
# Name:    readFile
# Desc:    General file reader that reads the contents of a file into an
#          array and returns the array
# Inputs:  file
# Outputs: array
# -------------------------------------------------------------------------
sub readFile {

    my ($fh) = shift;
    my @lines;

    open (FILE, "$fh") or die "Can't open file = $fh \n";
    @lines = <FILE>;
    close FILE;

    return @lines;
 
}


# -------------------------------------------------------------------------
# Name:    checkBlocks
# Desc:    Checks to see if any blocking processes are running
# Inputs:  Block list
# Outputs: 0 or error message
# -------------------------------------------------------------------------
sub checkBlocks {

    my $list = shift;
    my @results;

    # get a list of running processes
    my $command = "ps";
    my @args = ("ax");
    my ($stdout, $stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($command, @args);

    # check if any of the listed procs are running
    my @procs = split / /, $list;
    if ($success) {

        foreach my $proc (@procs) {
            if ($stdout =~ /$proc/) {
                push @results, $proc;
            }
        }

    }
    else {
        croak "Unable to execute $command : $stderr";
    }

    # Evaulate and return
    if (@results) {
        my $line = join " ", @results;
        my $message
            = "The following blocking process were detected: "
            . "$line \n"
            . "Please run the script when these processes are "
            . "not running, or consult the block list in your "
            . "configuration file.\n";
        return $message;
    }
    else {
        return 0;
    }

}   





# -------------------------------------------------------------------------
# Name:    clearLog
# Desc:    Deletes a given log file, if it exists
# Inputs:  file
# Outputs: none
# -------------------------------------------------------------------------
sub clearLog {

    my $log = shift;
    if (-e $log) {
        system("rm -f $log") == 0 or die "I can't remove the file $log";
    }
    return 0;

}




# -------------------------------------------------------------------------
# Name:    runCommand
# Desc:    General command execution subroutine that runs a command when
#          we want to capture its output.  Command dies when there is
#          any non-zero exit status or anything captured from stderr
# Inputs:  command, args (optional)
# Outputs: String of stdout
# -------------------------------------------------------------------------
sub runCommand {

    use IO::CaptureOutput qw(capture qxx qxy);
    
    my ($command, @args) = @_;

    my ($stdout, $stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($command, @args);
     
     if ( (!$success) or ($exit_code > 0) or ($stderr) ) {
        my $argLine = join(" ", @args);
        my $message
            = "Caught non-zero exit status $exit_code \n"
            . "This command failed: \n "
            . "$command $argLine \n "
            . "Error:\n $stderr"
            ;
            croak $message;
     } 
     else {
        chomp  $stdout;
        return $stdout;
     }
    
}



# -------------------------------------------------------------------------
# Name:    runQuietCommand
# Desc:    Same as above except this version will not die on failure and
#          will instead "quietly" return any errors for further evaluation
#          by the caller
# Inputs:  command, args (optional)
# Outputs: String of stdout, string of stderr (if any)
# -------------------------------------------------------------------------
sub runQuietCommand {

    use IO::CaptureOutput qw(capture qxx qxy);
    
    my ($command, @args) = @_;

    my ($stdout, $stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($command, @args);
     
     if ( (!$success) or ($exit_code > 0) or ($stderr) ) {
        chomp $stderr;
        return (0, $stderr);
     } 
     else {
        chomp  $stdout;
        return ($stdout, 0);
     }
    
}





# -------------------------------------------------------------------------
# Name:    sendEmail
# Desc:    Sends email out
# Inputs:  To, From, Subject, Body
# Outputs: none
# -------------------------------------------------------------------------
sub sendEmail {

    my ($arg_ref) = @_;

    my $to      = $arg_ref->{to};
    my $from    = $arg_ref->{from};
    my $subject = $arg_ref->{subject};
    my $body    = $arg_ref->{body};

    my $sendmail = '/usr/sbin/sendmail';
    open(MAIL, "|$sendmail -oi -t");
        print MAIL "From: $from\n";
        print MAIL "To: $to\n";
        print MAIL "Subject: $subject\n\n";
        print MAIL "$body";
    close(MAIL);
    
} # end sendEmail



# -------------------------------------------------------------------------
# Name:    sendMarc
# Desc:    Sends marc records out as an attachment
# Inputs:  To, From, Subject, Body, folder with records
# Outputs: none?
# -------------------------------------------------------------------------
sub sendMarc {

    use MIME::Lite;
    use Path::Class;

    my ($arg_ref) = @_;

    my $to      = $arg_ref->{to};
    my $from    = $arg_ref->{from};
    my $subject = $arg_ref->{subject};
    my $body    = $arg_ref->{body};
    my $folder  = $arg_ref->{folder};

    my $source  = Path::Class::Dir->new( $folder);
    my @records = DRA::readDirectory( $source, "txt" );

    my $msg = MIME::Lite->new(
        From    => $from,
        To      => $to,
        Subject => $subject,
        Type    => 'multipart/mixed',
    );

    $msg->attach(
        Type     => 'TEXT',
        Data     => $body,
    );

    foreach my $r (@records) {

        my $path = Path::Class::File->new( $folder, $r );

        $msg->attach(
            Type     => 'text/plain',
            Path     => $path,
            Filename => $r,
        );

    }

    $msg->send;

}




# -------------------------------------------------------------------------
# Name:    getLibraryName
# Desc:    Parses file name and reformats
# Inputs:  Filename, variations id
# Outputs: New filename, errors
# -------------------------------------------------------------------------
sub getLibraryName {

    my $name = shift;
    my $id   = shift;
    my $newName;

    my %numbersToLetters = (
        "001" => "a", 
        "002" => "b", 
        "003" => "c", 
        "004" => "d", 
        "005" => "e", 
        "006" => "f", 
        "007" => "g", 
        "008" => "h", 
        "009" => "i", 
        "010" => "j", 
        "011" => "k", 
        "012" => "l", 
        "013" => "m", 
        "014" => "n", 
        "015" => "o"
    );
 
    # Get the filename and determine if it has a three-digit part number
    # if so, then use that to determine its letter designation
    # otherwise, its letter will always be "a"
    my ($file, $ext) = split /\./, $name;
    my @p = split /_/, $file;
    my $part = pop(@p);
    if ($part =~ /\d\d\d/) {
        $newName = $id . $numbersToLetters{$part} . "." . $ext;
    }
    else {
        $newName = $id . "a" . "." . $ext;
    }
    
    return $newName;

}





# -------------------------------------------------------------------------
# Name:    readDirectory
# Desc:    Reads the entire contents of a directory and returns array
#          of names or only files ending in a given extension.
#         
# Inputs:  full path to directory, optional file extension
# Outputs: array of filenames
# -------------------------------------------------------------------------
sub readDirectory {

    my ($path, $ext) = @_;
    my @files;
    my @returns;    

    opendir(DIR, "$path") 
        or croak "readDirectory subroutine: Can't read directory $path\n";
    @files = readdir(DIR);
    close(DIR);
    
     foreach my $f (@files) {
     
             if ( ($ext) and ( $f =~ m/\.\Q$ext\E$/ ) ) {
                     push (@returns, $f);
             } elsif ( (!$ext) and ( $f !~ m/^\./ ) ) {
                     push (@returns, $f);
             }
         
     }
    
    return @returns;

}



# -------------------------------------------------------------------------
# Name:   checkLog
# Desc:   Greps a log for a pattern, or just returns a count of lines
# Inputs: Log, pattern (optional)
# Ouputs: Numerical count of lines with matches
# -------------------------------------------------------------------------
sub checkLog {

    my ($log, $pattern) = @_;
    my $count = 0;
    
    open(FILE, "$log") or die "Can't read file $log \n";
    while (<FILE>) {
        if ($pattern) {
            $count++ if ($_ =~ /$pattern/);
        } 
        else {
            $count++;
        }
    }
    close FILE;
    
    return $count;
    
}



# -------------------------------------------------------------------------
# Name:    checkProjectDir
# Desc:    Checks the naming of the project directory to ensure 
#          consistency and returns dated portion and hall name
# Inputs:  projectDir, list of halls
# Outputs: project directory, hall name, variations id, 
#          MDSS prefix and errors (if any)
# -------------------------------------------------------------------------
sub checkProjectDir {
    
    my ($projectDir, $hallList) = @_;
    my @errors;
    my $line;
    my $prefix;

    # Get the last directory in the path
    my $d = Path::Class::Dir->new($projectDir);
    my $s = $d->stringify;
    my @p = split(/\/|:|\\/, $s);
    my $dir = pop(@p);

    # Parse project directory path for elements
    my @parts = split(/_/, $dir);

    # Check for correctly formatted date and return error message
    if ($parts[0] !~ /^[0-9]{8,8}$/) {
        push (@errors, "$dir - Date not formatted correctly");
    }
    
    # Check for correctly formatted time and return error message
    if ($parts[1] !~ /^[0-9]{4,4}$/) {
        push (@errors, "$dir - Time not formatted correctly");
    }

    # Check Variations ID
    if ($parts[3] !~ /^[a-z]{3,3}[0-9]{4,4}$/) {
        push (@errors, "$dir - Variations ID not in correct format");
    }

    # Check the hall from a list of possible halls
    if ($hallList !~ /$parts[2]/) {
        push (@errors, "$dir - Hall not found!");
    }

    # Build MDSS prefix
    my @mdssParts = ("jsom", $parts[0], $parts[1], $parts[2]);


    # Evaluate
    if (@errors) {
        $line   = "\n\t" . join("\n\t", @errors) . "\n";
        $prefix = 0;
    }
    else {
        $line   = 0;
        $prefix = join "_", @mdssParts;
    }
    
    return ($dir, $parts[2], $parts[3], $prefix, $line);

}




# -------------------------------------------------------------------------
# Name:    checkDirectoryContents
# Desc:    Checks the contents of a given directory to make sure they conform
#          to the correct naming conventions Inputs:  directory
#          base name, such as "access" or "preservation"   
#          list of file types to check
#          Variations ID
# Outputs: Errors or null to indicate success
# -------------------------------------------------------------------------
sub checkDirectoryContents {

    my ($arg_ref) = @_;

    my $directory = $arg_ref->{dir};
    my $base      = $arg_ref->{base};
    my $list      = $arg_ref->{list};
    my $varid     = $arg_ref->{varid};

    my @errors;
    my @fileTypes = split(/ /, $list);
    push @fileTypes, "wav"; # we always check for .wav files
    
    # Build hash of files according to type and report on any missing types
    my %files;
    foreach my $ext (@fileTypes) {
        my @list = DRA::readDirectory($directory, $ext);
        if ( scalar(@list) == 0 ) {
            push @errors, "Missing file type $ext";
        }
        else {
            $files{$ext} = [ @list ];
        }
    }

    # Check that the number of rtf and wav files match on our preservation
    # directory
    if ($base eq "preservation") {
        my $wav_ref = $files{wav};
        my $rtf_ref = $files{rtf};
        if( scalar(@$wav_ref) != scalar(@$rtf_ref) ) {
            push @errors, "Number of wave and rtf files does not match";
        }
    }
    
    # Check name of each file
    foreach my $ext (keys %files) {

        my $_ref = $files{$ext};
        foreach my $file (@$_ref) {
            
            # Parse out the partsof our filename If it has already been
            # renamed with the jsom prefix it should have seven parts, if not,
            # only three
            my ($f, $ext) = split(/\./, $file);
            my @parts = split(/_/, $f);
            my ($id, $name, $part);

            if ( $parts[0] =~ /^jsom/ ) {
            
                $id   = $parts[4];
                $name = $parts[5];
                $part = $parts[6];
                if ( scalar(@parts) != 7 ) {
                    push @errors, "$file - Wrong number of parts";
                }
            
            } 
            else {
            
                ($id, $name, $part) = @parts;
                if ( scalar(@parts) != 3 ) {
                    push @errors, "$file - Wrong number of parts";
                }
            
            }

            if ($id !~ /^[a-z]{3,3}[0-9]{4,4}$/) {
                push @errors, "$file - Variations ID is incorrect";
            }

            if ($varid ne $id) {
                push @errors, "$file - ID does not match project folder";
            }
                
            # We want our wave files to match the given $base paramenter
            if ( ($ext =~ /wav/) and ($name !~ /^$base/) ) {
                push @errors, "$file - Wave file name does not match $base";
            }
            
            # Other files can be either...
            if ($name !~ /^[access|preservation]/) {
                push @errors, "$file - Has unknown name format";
            }

            if ( ($ext =~ /wav/) and ($name !~ /^$base\d\d\d\d$/) ) {
                push @errors, "$file - Bit rate and resoultion incorrect";
            }

            if ( ($ext =~ /wav|img/) and ($part !~ /^\d\d\d$/) ) {
                push @errors, "$file - Incorrect take number";
            }
            
            if ( ($ext =~ /rtf/) and ($name !~ /Rpt$/) ) {
                push @errors, "$file - Report filename incorrect";
            }

            if ( ($ext =~ /doc/) and ($name !~ /[CDLabel|DVDLabel]$/) ) {
                push @errors, "$file - CD/DVD label filename incorrect";
            }
            

        } # end foreach
   
    } # end foreach

    # Evaluate and return results 
    if ( scalar(@errors > 0) ) {
        my $line = "\n\t" . join("\n\t", @errors) . "\n";
        return $line; 
    }
    else {
        return 0;
    }

}



# -------------------------------------------------------------------------
# Name:    checkVideoDirectoryContents
# Desc:    Checks the contents of a video project directory.
# Inputs:  directory
# Outputs: errors, if any
# -------------------------------------------------------------------------

sub checkVideoDirectoryContents {

    my $dir   = shift;
    my $varId = shift;
    my @errors;

    my $typeList = "accessDVD preservationProRes422 preservationVideo";

    my @files = DRA::readDirectory($dir);
    foreach my $file (@files) {
        unless ($file =~ /^access$/) {
            my @parts = split /_/, $file;
            unless ($parts[0] =~ /^$varId/) {
                push @errors, "$file does not match Variations ID";
            }
            unless ($typeList =~ /$parts[1]/) {
                push @errors, "Incorrect filename type: $parts[1]";
            }
        }
    }

    if ($errors[0]) {
        my $line = join " -- ", @errors;
        return $line;
    }
    else {
        return 0;
    }


}

# -------------------------------------------------------------------------
# Name:    checkSubdirectories
# Desc:    Checks that any subdiretory, usually in the root of the
#          preservation folder, conforms to the correct naming scheme. Any
#          subfolder should have the Variations ID prefixed to it, separated
#          by a "_" 
# Inputs:  directory
# Outputs: errors, if any
# -------------------------------------------------------------------------

sub checkSubdirectories {

    my ($root, $id) = @_;
    my @errors;
    my @list = readDirectory($root);
    
    foreach my $item (@list) {
        
        my $path = Path::Class::Dir->new($root, $item);
        if ( -d $path ) {
            
            my @parts = split /_/, $item;
            if ( (scalar @parts == 1) and ($item !~ /access/) ) {
                my $message = "$item - misnamed or incorrect separator (_)";
                push @errors, $message;
            }

            if (     (scalar @parts < 3) 
                 and ($parts[0] !~ /$id/) 
                 and ($item !~ /access/) ) 
            {
                my $message = "$item - does not begin with Variations ID";
                push @errors, $message;
            }

        }

    }

    if (@errors) {
        my $line = join "\n", @errors;
        my $message
            = "These directories were misnamed: \n"
            . $line;
        return $message;
    }
    else {
        return 0;
    }

}


# -------------------------------------------------------------------------
# Name:    getAccessName
# Desc:    Returns formatted access file name from a given preservation name
# Inputs:  filename
# Outputs: filename
# -------------------------------------------------------------------------
sub getAccessName {

    my ($origFileName, $bitRate, $sampleRate) = @_;
    my $newAccessFileName;
    
    my @origFileNameAndExt = split (/\./, $origFileName);
    my @OrigFileNameParts  = split (/_/, $origFileNameAndExt[0]);
    my $shortSampleRate    = substr($sampleRate, 0, 2);

    # For files that only have 2 parts: vaa1234_preservationProgram.pdf, add a
    # _001
    if (scalar(@OrigFileNameParts) eq 2) {
        $newAccessFileName 
            = $OrigFileNameParts[0] 
            . "_" 
            . "access" 
            . $bitRate 
            . $shortSampleRate 
            . "_001"
            . "."
            . $origFileNameAndExt[1]
            ;
    }

    # For files that only have 3 parts: vaa1234_preservation2496_001.wav, rename
    if (scalar(@OrigFileNameParts) eq 3) {
        $newAccessFileName 
            = $OrigFileNameParts[0] 
            . "_" 
            . "access" 
            . $bitRate 
            . $shortSampleRate 
            . "_" 
            . $OrigFileNameParts[2] 
            . "." 
            . $origFileNameAndExt[1]
            ;
    }

    # Technically an error...
    if (    (scalar(@OrigFileNameParts) ne 2) 
        and (scalar(@OrigFileNameParts) ne 3) 
        and (scalar(@OrigFileNameParts) ne 7)
    ) {
        die "Access name and preservation name are the same";
    }

    # This catches files that have already been renamed and makes sure to keep the 
    # same name
    if (scalar(@OrigFileNameParts) eq 7) {
        $newAccessFileName 
            = $OrigFileNameParts[0] 
            . "_" 
            . $OrigFileNameParts[1] 
            . "_" 
            . $OrigFileNameParts[2] 
            . "_" 
            . $OrigFileNameParts[3] 
            . "_" 
            . $OrigFileNameParts[4] 
            . "_" 
            . "access" 
            . $bitRate 
            . $shortSampleRate 
            . "_" 
            . $OrigFileNameParts[6] 
            . "." 
            . $origFileNameAndExt[1]
            ;

    }

    return $newAccessFileName;

}


# -------------------------------------------------------------------------
# Name:    getVarid
# Desc:    Gets the Variations ID from a properly formatted project 
#          directory.  This assumes you've already checked the syntax
#          of the directory with the checkProjectDir subroutine
# Inputs:  directory
# Outputs: Variations ID
# -------------------------------------------------------------------------
sub getVarid {
    
    my $dir = shift;

    my @parts = split /_/, $dir;
    my $id    = pop @parts;

    if ($id =~ /[a-z]{3,3}[0-9]{3,3}/) {
        return $id;
    }
    else {
        return 0;
    }

}



# -------------------------------------------------------------------------
# Name:    getProject
# Desc:    Returns the dated directory portion of a project directory path
#          If you're checking a project directory for the first time, it's
#          better to use the checkProjectDir routine instead
# Inputs:  directory
# Outputs: dated portion
# -------------------------------------------------------------------------
sub getProject {

    my ($dir) = shift;

    my @parts    = split /\//, $dir;
    my $datedDir = pop @parts;

    if ($datedDir =~ /^[0-9]{8,8}_[0-9]{4,4}/) {
        return $datedDir;
    }
    else {
        return 0;
    }

}


# -------------------------------------------------------------------------
# Name:    checkConversion
# Desc:    Checks the bit and sample rate using the metadata in the header of
#          the wave file.  
# Inputs:  Audio file
# Outputs: error message
# -------------------------------------------------------------------------
sub checkConversion {
    
    use Audio::Wav;
    my ($arg_ref) = @_;
    my @errors;

    my $file    = $arg_ref->{file};
    my $samples = $arg_ref->{samples};
    my $bits    = $arg_ref->{bits};

    my $wav  = new Audio::Wav;
    my $read = $wav->read($file);
    $details = $read->details();
    
    while ( my ($key, $value) = each(%$details) ) {

        if ( ($key =~ /sample_rate/) and ($value != $samples ) ) {
            my $message 
                = "Error in $file:\n "
                . "$key is . $value";
            push (@errors, $message);
        }

        if ( ($key =~ /bits_sample/) and ($value != $bits) ) {
            $message 
                = "Error in $file: \n" 
                . "$key is $value";
            push (@errors, $message);
        }

    }

    if (@errors) {
        my $message = join "\n", @errors;
        return $message
    }
    else {
        return 0;
    }

} 



# -------------------------------------------------------------------------
# Name:    createMD5
# Desc:    Creates md5 sum for a given file on a specific platform.
#          in this case, Mac OS X server, and outputs a UNIX style md5
#          checksum file.  
# Inputs:  full path to file, name of output md5 file
# Outputs: file with .md5 extension in the same location and errors
# -------------------------------------------------------------------------
sub createMD5 {

    my $file = shift;
    my $out  = shift;
    my @errors;
    my $outfile;
    my $source = Path::Class::File->new($file);
    my $parent = $source->parent;
    
    my $openssl = "/usr/bin/openssl";
    my @args    = ("dgst", "-md5", $file);
    my ($stdout, $stderr, $success, $exit_code) 
            = IO::CaptureOutput::capture_exec($openssl, @args);
    
    if ($success) {
        my ($junk, $sum) = split / /, $stdout;
        chomp $sum;
        $outfile = $out . ".md5";
        my $path = Path::Class::File->new($parent, $outfile);

        # Write out Linux-style md5 file
        # Format is critical here... there must be 2 spaces between the sum
        # and the filename, with nothing else in the file
        # Ex:
        #>>Start of file
        #[xxxxxxxxxxxxxxxxxxxxxxx]  [filename]
        #<<EOF
        open (FILE, ">$path") or die "Can't open file = $path !\n";
        print FILE $sum . "  " . $out . "\n";
        close FILE;
        return ($outfile, 0);
    }
    else {
        return (0, $stderr);
    }

}


# -------------------------------------------------------------------------
# Name:    getMD5
# Desc:    Gets the md5 sum from the file outputted by createMD5
# Inputs:  full path to file
# Outputs: md5 sum
# -------------------------------------------------------------------------
sub getMD5 {

    my $file = shift;
    open (FILE, $file) or croak "Can't open $file \n";
    my @line = <FILE>;
    close (FILE);
    chomp @line;
    my ($md5, $junk) = split / /, $line[0];
    return $md5;

}


# -------------------------------------------------------------------------
# Name:    sendSCP
# Desc:    Sends a file to a remote destination via sco
# Inputs:  user, ssh key file, list of options, source and destination
#          files.
# Outputs: error message
# -------------------------------------------------------------------------

sub sendSCP {
    
    my ($arg_ref) = @_;

    my $user = $arg_ref->{user};
    my $key  = $arg_ref->{key};
    my $opts = $arg_ref->{opts};
    my $src  = $arg_ref->{source};
    my $dst  = $arg_ref->{dest};
    my $host = $arg_ref->{host};

    my $scp    = "/usr/bin/scp";
    my @args   = split / /, $opts;
    my $remote = $user . "@" . $host . ":" . $dst; 
    push @args, "-i", $key, $src, $remote;

    my ($stdout, $stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($scp, @args);

    if ($success) {
        return 0;
    }
    else {
        return "Transfer failed: $stderr";
    }

}






# -------------------------------------------------------------------------
# Name:    checkMD5
# Desc:    Checks a md5 sum on a remote server
# Inputs:  md5 file, username, host, key and ssh options
# Outputs: error message
# -------------------------------------------------------------------------

sub checkMD5 {

    my ($arg_ref) = @_;

    my $file = $arg_ref->{md5};
    my $dir  = $arg_ref->{dir};
    my $user = $arg_ref->{user};
    my $key  = $arg_ref->{key};
    my $opts = $arg_ref->{opts};
    my $host = $arg_ref->{host};
    my $ssh  = $arg_ref->{ssh};

    my $remoteCommand = "cd $dir && md5sum -c $file";
    my @args = split / /, $opts;
    push @args, "-l", $user, "-i", $key, $host, $remoteCommand;

    my ($stdout, $stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($ssh, @args);

    if ($success) {
        if ($stdout =~ /OK/) {
            return 0;
        }
        else {
            return $stdout;
        }
    }
    else {
        return $stderr;
    }

}




# -------------------------------------------------------------------------
# Name:    sendToBurnFolder
# Desc:    Copies designated wave files to the designated folder for burning
#          to CD
# Inputs:  
# Outputs: 
# -------------------------------------------------------------------------
#sub sendToBurnFolder {
#
# $concertType = $details->{info}->{genre};
## The following was used to filter out Graduate recital since we didn't burn them to CD. It is commented out to send all concerts to be burned. 20090629-TEG
## if (($concertType eq "Graduate Recital") or ($concertType eq "Artist Diploma") or ($concertType eq "Graduate Lecture/Recital") or ($concertType eq "Graduate Chamber Recital")) {
##  open(ToBeBurnedLog, ">>$sentToBeBurnedLogPath") or die "Unable to open $sentToBeBurnedLogPath: $! \n";
##   print ToBeBurnedLog $currentTime . ":\t Project genre is $concertType, no burn needed\n";
##  close(ToBeBurnedLog);
## }
# if (!-e $sentToBeBurnedLogPath) { # and ($concertType ne "Graduate Recital")) {        # If the concert hasn't been sent to be burned, do so...
#  local $mkDir = "mkdir -p " . $needToBeBurnedPath . $datedDir;
#  `$mkDir`;
#  getCurrentTime;
#  open(ToBeBurnedLog, ">>$sentToBeBurnedLogPath") or die "Unable to open $sentToBeBurnedLogPath: $! \n";
#   print ToBeBurnedLog $currentTime . ":\t Created project folder\n";
#   print ToBeBurnedLog $currentTime . ":\t Copying all wavs\n";
#  close(ToBeBurnedLog);
##  local $cpCommand = "cp " . $accessDir . "*.wav " . $needToBeBurnedPath . $datedDir . "\/";
##  `$cpCommand`;
#  foreach $accessDesiredExt (@requiredAccessFilesTypes, "wav", "img") {
#   getCurrentTime;
#   local $cpCommand = "cp " . $accessDir . "*." . $accessDesiredExt . " " . $needToBeBurnedPath . $datedDir . "\/";
#   `$cpCommand`;
#   open(ToBeBurnedLog, ">>$sentToBeBurnedLogPath") or die "Unable to open $sentToBeBurnedLogPath: $! \n";
#    print ToBeBurnedLog $currentTime . ":\t Copied all " . $accessDesiredExt . "\n";
#   close(ToBeBurnedLog);
#  }
# }
#}
#}





# -------------------------------------------------------------------------
# Name:    getMDSSnames
# Desc:    Outputs a text file of MDSS names formatter for inclusion into
#          IUCAT as well as writing a data file to the root of directory 
#          it is given that has all the same info and is used for 
#          subsequent routines 
# Inputs:  project directory, list of MDSS extensions, prefix to use when
#          renaming the files, a list of filenames to omit and the name of the
#          datafile to write stored information 
# Outputs: Returns text file, writes file to root of the given directory
# -------------------------------------------------------------------------
sub getMDSSnames {

    my ($arg_ref) = @_;

    my $dir      = $arg_ref->{dir};
    my $list     = $arg_ref->{list};
    my $prefix   = $arg_ref->{prefix};
    my $omitList = $arg_ref->{omits};
    my $datafile = $arg_ref->{datafile};
    my $logDir   = $arg_ref->{logdir};

    my @access;
    my @preservation;
    my @tar;

    my $r         = Path::Class::Dir->new($dir);
    my $root      = $r->absolute; # get absolute path for projectDir
    my @contents  = DRA::readDirectory($root);
    foreach my $elem (@contents) {

        my $path = Path::Class::Dir->new($root, $elem);
        if ( -d $path ) {
            if ($elem =~ /^access$/) {
                
                # Process the files in the access subdir
                my $aDir    = Path::Class::Dir->new($root, $elem);
                my @files   = DRA::readDirectory($aDir);

                foreach my $file (@files) {

                    # Ignore any subdirectories in the access folder or md5
                    # files created in other scripts
                    my $path = Path::Class::File->new($aDir, $file);
                    if (-f $path and ($file !~ /md5$/) ) {
                        my ($name, $ext) = split /\./, $file;

                        if (    ($list     =~ /\b$ext\b/)
                            and ($omitList !~ /$name/))
                        {

                            # Process files that haven't been renamed
                            # otherwise, just add the name to the hash as-is
                            if ($name !~ /^$prefix/) {
                                # Add file with new name to access hash
                                my $newname = $prefix . "_" . $file;
                                push @access, $newname;
                            }
                            else {
                                push @access, $file;
                            }

                        }
                    }
                }

            }
            else {

                # Add any directory not called "access" to tar hash
                # Check that the file hasn't been renamed already
                if ($elem !~ /^$prefix/) {
                    my $newname
                        = $prefix 
                        . "_" 
                        . $elem 
                        . ".tar";
                    push @tar, $newname;
                }
                else {
                    push @tar, $elem;
                }

            }

        }
        else {

            # Process the files in the root diretory
            # Ignore md5 files from other scripts
            my ($name, $ext) = split /\./, $elem;
            if (    ($list     =~ /$ext/)
                and ($omitList !~ /$name/) 
                and ($elem     !~ /md5$/) ) 
            {

                # Add file with new name to the preservation hash
                # Check that the file hasn't been renamed
                if ($elem !~ /^$prefix/) {
                    my $newname = $prefix . "_" . $elem;
                    push @preservation, $newname
                }
                else {
                    push @preservation, $elem;
                }

            }

        }

    }


    # Create file to store filename information for later use
    use Storable;
    my %data = ( 
        prefix       => $prefix,
        access       => \@access, 
        preservation => \@preservation, 
        tar          => \@tar
    );
    my $dataPath = Path::Class::File->new($logDir, $datafile);
    store \%data, $dataPath;


    # Create formatted text file for includsion in IUCAT
    my $separator = "; ";
    my $output
        = "Preservation files stored on MDSS in \"audiopro\" account: ";
    my $p_line = join $separator, @preservation;
    $output .= $p_line;
    if (@tar) {
        my $t_line = join $separator, @tar;
        $output .= $separator . $t_line . ".\n\n";
    }
    else {
        $output .= ".\n\n";
    }

    $output
        .= "Access files stored on MDSS in \"audiopro\" account: ";
    my $a_line = join $separator, @access;
    $output .= $a_line . ".\n";

    return $output;

}





# -------------------------------------------------------------------------
# Name:    getMDSSdata
# Desc:    Returns hashes of filenames from the datafile that is first
#          created by the getMDSSnames subroutine
# Inputs:  MDSS filename datafile
# Outputs: 3 hashes: access, preservation, tar
# -------------------------------------------------------------------------
sub getMDSSdata {

    my $fh = shift;
    my %access;
    my %preservation;
    my %tar;

    my @lines = DRA::readFile($fh);
    my $data = join " ", @lines;

    use Data::Dumper;
    $d = Dumper($data);

    print $d;


    return (%access, %preservation, %tar);


}





# -------------------------------------------------------------------------
# Name:    hsiPut
# Desc:    Puts file to remote location using hsi
# Inputs:  
# Outputs: 
# -------------------------------------------------------------------------
sub hsiPut {

    my ($arg_ref) = @_;

    my $source  = $arg_ref->{source};
    my $dest    = $arg_ref->{dest};
    my $hsi     = $arg_ref->{hsi};
    my $optLine = $arg_ref->{opts};
    my $ports   = $arg_ref->{ports};
    my $keytab  = $arg_ref->{keytab};

    my @opts                      = split / /, $optLine;
    my $portRange                 =  "ncacn_ip_tcp[" . $ports . "]";
    $ENV{"HPSS_PFTPC_PORT_RANGE"} = $portRange;

    my @args;
    push @args, @opts;
    push @args, $keytab;
    push @args, "put", $source, ":", $dest;

    my ($stdout, $stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($hsi, @args);
    
    if (!$success) {
        print "stdout = " . $stdout . "\n";
        return $stderr;
    }
    else {
        return 0;
    }

}




# -------------------------------------------------------------------------
# Name:    hsiCheck
# Desc:    Checks an hsi transfer using an md5 sum
# Inputs:  
# Outputs: 
# -------------------------------------------------------------------------
sub hsiCheck {
    
    my ($arg_ref) = @_;

    my $file      = $arg_ref->{file};
    my $path      = $arg_ref->{path};
    my $hsi       = $arg_ref->{hsi};
    my $optLine   = $arg_ref->{opts};
    my $ports     = $arg_ref->{ports};
    my $temp      = $arg_ref->{temp};
    my $keytab    = $arg_ref->{keytab};
    
    my @errors;
    my @opts        = split / /, $optLine;
    push @opts, $keytab;

    my $md5         = $file . ".md5";
    my $origMD5     = $md5  . ".orig";
    my $localMD5    = Path::Class::File->new($temp, $origMD5);
    my $remoteMD5   = Path::Class::File->new($path, $md5);
    my $localFile   = Path::Class::File->new($temp, $file);
    my $remoteFile  = Path::Class::File->new($path, $file);

    # Set HSI environment variable
    my $portRange                 =  "ncacn_ip_tcp[" . $ports . "]";
    $ENV{"HPSS_PFTPC_PORT_RANGE"} = $portRange;

    # Pull down md5 and file for checking
    my @files = ($file, $md5);
    foreach my $file (@files) {

        my @args;
        push @args, @opts;
        if ($file =~ /\.md5$/) {
            push @args, "get", $localMD5, ":", $remoteMD5;
        } 
        else {
            push @args, "get", $localFile, ":", $remoteFile;
        }
        my ($stdout, $stderr, $success, $exit_code) = 
            IO::CaptureOutput::capture_exec($hsi, @args);
        if (!$success) {
            push @errors, $stderr;
        }

    }

    # Compute md5 sum on newly downloaded file
    # Note: the DRA::createMD5 sub adds the md5 extension
    my ($check, $err) = DRA::createMD5($localFile, $file);
    if ($err) {
        push @errors, $err;
    }

    # Compare the two md5 files
    my $checkMD5   = Path::Class::File->new($temp, $check);
    my $diff       = "/usr/bin/diff";
    my @c_args     = ( $localMD5, $checkMD5 );
    my $result     = system($diff, @c_args);
    if ($result) {
        my $message = "Error! MD5 sums do not match";
        push @errors, $message;
    }

    # Remove local files
    my $remove  = "/bin/rm";
    my @r_args  = ( "-f", $localFile, $localMD5, $checkMD5 );
    my $cleanup = system( $remove, @r_args );
    if ($cleanup) {
        my $message = "Couldn't remove the MD5 check files";
        push @errors, $message;
    }

    # Evaluate errors and return
    if (@errors) {
        my $line = join " ", @errors;
        return $line;
    }
    else {
        return 0;
    }

}



# -------------------------------------------------------------------------
# Name:    htarSend
# Desc:    Sends a folder via htar using kinit utilities with a keytab. In
# order that the resulting paths in the tar file are comprehensible, the
# subroutine changes to the source directory
# Inputs:  Source folder, destination name (we'll add .tar to it later), the
# path to the htar command and various options
# Outputs: Returns 0 on success and error messages failure
# -------------------------------------------------------------------------
sub htarSend {

    my ($arg_ref) = @_;

    my $src      = $arg_ref->{src};
    my $parent   = $arg_ref->{parent};
    my $dest     = $arg_ref->{dest};
    my $htar     = $arg_ref->{htar};
    my $hopts    = $arg_ref->{htarOpts};
    my $keytab   = $arg_ref->{keytab};
    my $user     = $arg_ref->{user};
    my $ports    = $arg_ref->{ports};
    my $debug    = $arg_ref->{debug};

    my $destFile   = $dest;
    my @htarOpts   = split / /, $hopts;
    my @htarArgs   = ( "-c", "-f", $destFile, @htarOpts, $src );

    # Pesky environment variables
    my $portRange                 = "ncacn_ip_tcp[" . $ports . "]";
    $ENV{"HPSS_PFTPC_PORT_RANGE"} = $portRange;
    $ENV{"HPSS_PRINCIPAL"}        = $user; 
    $ENV{"HPSS_KEYTAB_PATH"}      = $keytab;
    $ENV{"HPSS_AUTH_METHOD"}      = "keytab";

    # Change to parent directory
    chdir($parent);

    # Send file via htar
    my ($stdout, $stderr, $not_success, $not_exit_code) = 
        IO::CaptureOutput::capture_exec($htar, @htarArgs);

    # Capture output for posterity...
    my $message
        = "STDOUT reported:\n"
        . $stdout
        . "\nSTERR reported:\n"
        . $stderr;


    # Verify transfer
    # HTAR's exit codes are shit.  We run another verify command to check that
    # the files made it over and use its exit code.
    my @htarVerifyArgs = ( "-K", "-f", $destFile);
    my ($v_stdout, $v_stderr, $success, $exit_code) = 
        IO::CaptureOutput::capture_exec($htar, @htarVerifyArgs);

    # Print out debug info
    if ($debug) {
        my $line = join " ", @htarArgs;
        print "htar opts    = [$line] \n\n";
        print "Exit code    = [$exit_code]\n\n";
        print "Success flag = [$success]\n\n";
        print "Message: \n $message \n\n";
    }

    if ($exit_code > 0) {
        return (1, $message);
    }
    else {
        return (0, $message);
    }

}



# -------------------------------------------------------------------------
# Name:    renamePdfs
# Desc:    Renames any pdfs to the DRA naming standard
#          Note: only handles up to 9 pdfs! But it should never get
#          that high.
# Inputs:  project directory, move command
# Outputs: errors
# -------------------------------------------------------------------------

sub renamePdfs {

    my $dir = shift;
    my $mv  = shift;
    
    my $error;
    my $count = 1;

    # rename any file with .PDF to .pdf
    my @upcase = DRA::readDirectory( $dir, "PDF" );
    foreach my $upfile (@upcase) {
        my ($f, $ext) = split(/\./, $upfile);
        my $newname = $f . ".pdf";
        my $newfile = Path::Class::File->new($dir, $newname);
        my $oldfile = Path::Class::File->new($dir, $upfile);
        system($mv, $oldfile, $newfile) == 0 or
            croak "Failed to rename pdf: $!";
    }

    # rename pdfs to correct format, if needed
    my @files = DRA::readDirectory( $dir, "pdf" );
    foreach my $file (@files) {

        my ($f, $ext) = split(/\./, $file);
        my @parts = split(/_/, $f);
        my ($id, $name, $part) = @parts;

        # If it's three or more parts, it's already been renamed
        if (scalar(@parts) < 3) {
            
            my $newname = $f . "_00" . $count . ".pdf";
            my $newfile = Path::Class::File->new($dir, $newname);
            my $oldfile = Path::Class::File->new($dir, $file);
            system($mv, $oldfile, $newfile) == 0 or
                croak "Filed to rename pdf: $!";

        }

        $count++;
        
    }

    return $error;

}



# -------------------------------------------------------------------------
# Name:    getMarc
# Desc:    Retrieves full path to a marc file from a given project directory
# Inputs:  project directory
# Outputs: filename or NULL
# -------------------------------------------------------------------------

sub getMarc {

    my $dir = shift;

    my $varid = DRA::getVarid( $dir );
    my $name  = $varid . "_SD_marc.txt";
    my $path  = Path::Class::File->new( $dir, $name );

    if (-e $path) {
        return $path;
    }
    else {
        return 0;
    }

}


# -------------------------------------------------------------------------
# Name:    jiraSubject
# Desc:    Creates subject line that is used in the Jira ticket
# Inputs:  project directory
# Outputs: string or 0
# -------------------------------------------------------------------------

sub jiraSubject {

    my $dir = shift;
    my $output;

    my $id = DRA::getVarid( $dir );
    $output = "Jira - IUPerf: " . $id;
    return $output;

}



# -------------------------------------------------------------------------
# Name:    jiraMessage
# Desc:    Creates message that is used in the body of the Jira ticket
# Inputs:  project directory
# Outputs: string or 0
# -------------------------------------------------------------------------

sub jiraMessage {

    use Audio::Wav;
    use Data::Dumper;

    my $dir = shift;
    my $message;
    my @lines;
    my $output;

    # Audio:Wav barfs out false errors so we must disable STDERR and STDOUT 
    # temporarily
    open (STDERR, ">/dev/null") or
        croak "Failed to disable STDERR";
    open (STDOUT, ">/dev/null") or
        croak "Failed to disable STDOUT";

    # Get detail from wave header
    my @waves  = DRA::readDirectory( $dir, "wav" );
    my $infile = Path::Class::File->new( $dir, $waves[0] );
    if ( -e $infile ) {

        my $header
            = "This ticket was automatically created by the Department of "
            . "Recording Arts\n";
            ;
        push @lines, $header;
        
        my $datedDir = DRA::getProject( $dir );
        my $concert  = "Concert: " . $datedDir;
        push @lines, $concert;

        my $wavFile = new Audio::Wav;
        my $wavRead = $wavFile -> read( $infile );
        my $wavDetl = $wavRead -> details( );
        
        foreach (
            "artist", 
            "genre",
            "keywords", 
            "creationdate",
            "copyright", 
            "subject"
        ) {
            my $what = $_;
            $what =~ s/\b(\w)/\U$1/g;
            my $line = $what . ": " . $wavDetl->{info}->{$_};
            push @lines, $line;
        }

        $output = join "\n", @lines;

     }
     else {
        
        $output 
            = "There was an error. Please contact audiopro\@indiana.edu to "
            . "obtain more information about this ticket";

     }

     close (STDERR);
     close (STDOUT);
     return $output;

}


# -------------------------------------------------------------------------
# Name:    checkAge
# Desc:    Finds the age in hours of the youngest file in a directory
# Inputs:  directory (usually the log directory)
# Outputs: integer representing hours
# -------------------------------------------------------------------------

sub checkAge {

    my $dir  = shift;
    my $path = Path::Class::Dir->new($dir);

    my @files = DRA::readDirectory($path, "log");
    my @times;
    foreach my $file (@files) {
        my $logPath = Path::Class::File->new($path, $file);
        my $time = (stat($logPath))[9];
        push @times, $time;
    }

    # sort times and return hours
    my @sorted = sort {$a <=> $b} @times;
    my $now = time();
    my $secs = $now - $sorted[0];
    my $hours = $secs / 3600;

    return $hours;

}


# -------------------------------------------------------------------------
# Name:    setPermissions
# Desc:    Recusively sets the permissions for a given folder
# Inputs:  directory 
# Outputs: none
# -------------------------------------------------------------------------

sub setPermissions {

    use File::Find;
    my $dir   = shift;
    my $user  = shift;
    my $group = shift;
    find(\&wanted, $dir);
    
    sub wanted { 
        if ( -d $File::Find::name) {
            my @args = ("755", $File::Find::name);
            system("chmod", @args) == 0
                or croak "Failed to chmod directory $File::Find::name : $!";
        }
        else {
            my @args = ("664", $File::Find::name);
            system("chmod", @args) == 0
                or croak "Failed to chmod file $File::Find::name : $!";
        }
    }

    my $ownership = $user . ":" . $group;
    my @args = ("-R", $ownership, $dir);
    system("chown", @args) == 0
        or croak "Failed to chown files : $!";

}

# -------------------------------------------------------------------------
# Name:    sshCommand
# Desc:    Runs command over ssh
# Inputs:  user, ssh key, host, command
# Outputs: stdout and stderr
# -------------------------------------------------------------------------

sub sshCommand {

    my ($arg_ref) = @_;
    
    my $user    = $arg_ref->{user};
    my $sshKey  = $arg_ref->{sshKey};
    my $host    = $arg_ref->{host};
    my $command = $arg_ref->{command};

    my $hostString = $user . "@" . $host;
    my @args = ( "-i", $sshKey, $hostString, $command);
    my ($stdout, $stderr) = DRA::runQuietCommand("ssh", @args);

    return ($stdout, $stderr);

}


1;

