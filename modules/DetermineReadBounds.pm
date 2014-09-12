# getReadBounds(readLength, indexLength)
#       Returns the 4 bound of each region where cycle < x is necessary to be within that region
#
# Ex 1: getReadBounds(150,5)
#       Read 1  cycle > 0 AND cycle <= 150              (Read 1 <= 150)
#       Index 1 cycle > 150 AND cycle <= 155            (Read 2 <= 155)
#       Index 2 cycle > 155 AND cycle <= 160            (Read 3 <= 160)
#       Read 2  cycle > 160 AND cycle <= 310            (Read 4 <= 310)
#
# Ex 2: getReadBounds(105,0) - no index
#       Read 1  cycle > 0 AND cycle <= 101
#       Index 1 cycle > 101 AND cycle <= 101 (No cycles)
#       Index 2 cycle > 101 AND cycle <= 101 (No cycles)
#       Read 2  cycle > 101 AND cycle <= 202

sub getReadBounds {
	my ($read1_L, $index1_L, $index2_L, $read2_L) = @_;
	my $read1_bound = $read1_L;
	my $read2_bound = $read1_bound+$index1_L;
	my $read3_bound = $read2_bound+$index2_L;
	my $read4_bound = $read3_bound+$read2_L;
	return ($read1_bound, $read2_bound, $read3_bound, $read4_bound);
	}
1;
