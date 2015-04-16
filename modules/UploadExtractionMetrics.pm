# ExtractionMetricsOut.bin stores raw data such as
# fwhm and raw intensities
#
# Byte 0: File version
# Byte 1: Length of each record
#
# Followed by a repeated 12-field, 38-byte structure:
#
# 2 bytes: lane							[uint16]
# 2 bytes: tile	 						[uint16]
# 2 bytes: cycle						[uint16]
# 4 bytes*4: fwhm for [ACGT]			[float]
# 2 bytes*4: raw intensity for [ACGT]	[unsigned short]
#
# 8 bytes: 	Composite C# dateTime field
#		2 bits representing "kind"
#		62 bits representing the number of 100 ns
#		intervals since Gregorian midnight, January
#		1st, 0001.

use strict;

sub uploadExtractionMetrics($$$) {
	my ($RunID, $binFile, $db) = @_;
	open(INPUT, $binFile) || die "Couldn't open $binFile";

	local $/;						# Slurp mode: 	Prevent incorrect newline interpretation of binary data
	my $line = <INPUT>;

	my @f = unpack("cc(SSSf4S4B64)*", $line);			# c: signed char [1 byte]
	my ($fileVersion, $numRecords) = ($f[0], $f[1]);	# S: unsigned short (uint16)	[2 bytes]
														# f: single precision float 	[4 bytes]
														# V: unsigned long (uint32) 	[4 bytes]
														# B: bit string - little endian?
	my $c = 2;
	my $count = 1;
	while (defined($f[$c])) {
		my 	($lane, $tile, $cycle, $fwhm_A, $fwhm_C, $fwhm_G, $fwhm_T, $int_A, $int_C, $int_G, $int_T, $timeBitString) =
			($f[$c+0], $f[$c+1], $f[$c+2], $f[$c+3], $f[$c+4], $f[$c+5], $f[$c+6], $f[$c+7], $f[$c+8], $f[$c+9], $f[$c+10], $f[$c+11]);

        my $query = q{
            INSERT
            INTO    MiSeqQC_ExtractionMetrics
                    (
                    RunID,
                    lane,
                    tile,
                    cycle,
                    fwhm_A,
                    fwhm_C,
                    fwhm_G,
                    fwhm_T,
                    intensity_A,
                    intensity_C,
                    intensity_G,
                    intensity_T
                    )
            VALUES  (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        };


        my $sth = $db->prepare($query);
        $sth->execute(
            $RunID,
            $lane,
            $tile,
            $cycle,
            $fwhm_A,
            $fwhm_C,
            $fwhm_G,
            $fwhm_T,
            $int_A,
            $int_C,
            $int_G,
            $int_T);

		$c+= 12;
		if ($count % 2500 == 0) { my @t = localtime(time); my $time = "$t[2]:$t[1]:$t[0]";  print "[$time] $RunID - ExtractionMetrics, record $count\n"; }
		$count++;
		}
	close(INPUT);						# File is large - close gracefully
	undef $line;						# Variable is large - clear gracefully
	$db->commit();
	print "Committed transaction for ExtractionMetrics!\n\n";
	}
1;
