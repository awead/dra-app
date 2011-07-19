#!/usr/bin/perl

use DRA;

my $name         = [folder];
my $projectDir   =
"/Volumes/audio/Concerts/Test/20101027_2000_mac_vab4321/jsom_20101027_2000_mac_vab4321_vab4321_multitrackPerformance";
my $remotePath   = 
my $htar         = "/usr/local/bin/htar";
my $htarOptLine  = "-H crc:verify=2 -v -Y auto";
my $kinit        = "/usr/bin/kinit";
my $kinitOptLine = "-k -t";
my $kdestroy     = "/usr/bin/kdestroy";
my $keytabFile   = "conf/HPSS_audio_awead.keytab";

my ($error, $htarMessage) = DRA::htarSend(
        {
            src       => $name,
            parent    => $projectDir,
            dest      => $remotePath,
            htar      => $htar,
            htarOpts  => $htarOptLine,
            kinit     => $kinit,
            kopts     => $kinitOptLine,
            kdestroy  => $kdestroy,
            keytab    => $keytabFile,
            }
    );



exit 0;
