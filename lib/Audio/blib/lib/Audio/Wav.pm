package Audio::Wav;

use strict;
use Audio::Wav::Tools;

use vars qw( $VERSION );
$VERSION = '0.06';

=head1 NAME

Audio::Wav - Modules for reading & writing Microsoft WAV files.

=head1 SYNOPSIS

    # copying a file and adding some cue points to the output file
    use Audio::Wav;
    my $wav = new Audio::Wav;
    my $read = $wav -> read( 'input.wav' );
    my $write = $wav -> write( 'output.wav', $read -> details() );
    print "input is ", $read -> length_seconds(), " seconds long\n";

    $write -> set_info( 'software' => 'Audio::Wav' );
    my $data;
    #read 512 bytes
    while ( defined( $data = $read -> read_raw( 512 ) ) ) {
	$write -> write_raw( $data );
    }
    my $length = $read -> length_samples();
    my( $third, $half, $twothirds ) = map int( $length / $_ ), ( 3, 2, 1.5 );
    my %samp_loop = (
	'start'	=> $third,
	'end'	=> $twothirds,
    );
    $write -> add_sampler_loop( %samp_loop );
    $write -> add_cue( $half, "cue label 1", "cue note 1" );
    $write -> finish();


    # splitting a multi-channel file to seperate mono files (slowly!);
    use Audio::Wav;
    my $read = $wav -> read( '4ch.wav' );
    my $details = $read -> details();
    my %out_details = map { $_ => $details -> {$_} } 'bits_sample', 'sample_rate';
    $out_details{'channels'} = 1;
    my @out_files;
    my $in_channels = $details -> {'channels'};
    foreach my $channel ( 1 .. $in_channels ) {
	push @out_files, $wav -> write( 'multi_' . $channel . '.wav', \%out_details );
    }

    while ( 1 ) {
	my @channels = $read -> read();
	last unless @channels;
	foreach my $channel_id ( 0 .. $#channels ) {
	    $out_files[$channel_id] -> write( $channels[$channel_id] );
	}
    }

    # not entirely neccessary as finish is done in DESTROY now (if the file hasn't been finished already).
    foreach my $write ( @out_files ) {
	$write -> finish();
    }


=head1 NOTES

All sample positions are now in sample offsets (unless option '.01compatible' is true).

There is now *very* basic support for WAVEFORMATEXTENSIBLE (in fact it only recognises that the file is in this format).
The key 'wave-ex' is used in the detail hash to denote this format when reading or writing.
I'd like to do more with this, but don't have any hardware or software to test these files, also don't really have any spare time to do the implementation at present.

One day I plan to learn enough C to do the sample reading/ writing in XS, but for the time being it's done using pack/ unpack in Perl and is slow.
Working with the raw format doesn't suffer in this way.

It's likely that reading/ writing files with bit-depth greater than 16 won't work properly, I need to look at this at some point.

=head1 DESCRIPTION

These modules provide a method of reading & writing uncompressed Microsoft WAV files.

=head1 SEE ALSO

    L<Audio::Wav::Read>

    L<Audio::Wav::Write>

=head1 METHODS

=head2 new

Returns a blessed Audio::Wav object.
All the parameters are optional and default to 0

    my %options = (
	'.01compatible'		=> 0,
	'oldcooledithack'	=> 0,
	'debug'			=> 0,
    );
    my $wav = Audio::Wav -> new( %options );

=cut

sub new {
    my $class = shift;
    my $tools = Audio::Wav::Tools -> new( @_ );
    my $self =	{
	'tools'		=> $tools,
    };
    bless $self, $class;
    return $self;
}

=head2 write

Returns a blessed Audio::Wav::Write object.

    my $details = {
	'bits_sample'	=> 16,
	'sample_rate'	=> 44100,
	'channels'	=> 2,
    };

    my $write = $wav -> write( 'testout.wav', $details );

See L<Audio::Wav::Write> for methods.

=cut

sub write {
    my $self = shift;
    my $file = shift;
    my $details = shift;
    require Audio::Wav::Write;
    my $write = Audio::Wav::Write -> new( $file, $details, $self -> {'tools'} );
    return $write;
}

=head2 read

Returns a blessed Audio::Wav::Read object.

    my $read = $wav -> read( 'testout.wav' );

See L<Audio::Wav::Read> for methods.

=cut

sub read {
    my $self = shift;
    my $file = shift;
    require Audio::Wav::Read;
    my $read = Audio::Wav::Read -> new( $file, $self -> {'tools'} );
    return $read;
}


=head2 set_error_handler

Specifies a subroutine for catching errors.
The subroutine should take a hash as input. The keys in the hash are 'filename', 'message' (error message), and 'warning'.
If no error handler is set, die and warn will be used.

    sub myErrorHandler {
	my( %parameters ) = @_;
	if ( $parameters{'warning'} ) {
	    # This is a non-critical warning
	    warn "Warning: $parameters{'filename'}: $parameters{'message'}\n";
	} else {
	    # Critical error!
	    die "ERROR: $parameters{'filename'}: $parameters{'message'}\n";
	}
    }
    $wav -> set_error_handler( \&myErrorHandler );


=cut

sub set_error_handler {
    my $self = shift;
    $self -> {'tools'} -> set_error_handler( @_ );
}

=head1 AUTHORS

    Nick Peskett (see http://www.peskett.co.uk/ for contact details).
    Kurt George Gjerde <kurt.gjerde@media.uib.no>. (0.02-0.03)

=cut

1;
__END__
