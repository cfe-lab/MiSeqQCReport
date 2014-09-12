# QualityMetricsOut.bin stores the number of clusters
# in each Q-value bin for each (tile,cycle)
#
# Byte 0: File version
# Byte 1: Length of each record
# 
# Followed by a repeated 53 field, 206-byte structure:
#
# 2 bytes: lane							[uint16]
# 2 bytes: tile 						[uint16]
# 2 bytes: cycle 						[uint16]
# 4 bytes x 50: # clusters in Q1-Q50  	[uint32]

use strict;

sub uploadQualityMetrics($$$) {
	my ($RunID, $binFile, $db) = @_;
	open(INPUT, $binFile) || die "Couldn't open $binFile";

	local $/;							# Slurp mode: 	Prevent incorrect newline interpretation of binary data
	my $line = <INPUT>;					#				Loads entire contents of file at once

	my @f = unpack("cc(SSSV50)*", $line);				# c: signed char [1 byte]
	my ($fileVersion, $numRecords) = ($f[0], $f[1]);	# S: unsigned short (uint16) [2 bytes]
														# V: unsigned long (uint32) [4 bytes]
	my $c = 2;
	my $count = 1;
	while (defined($f[$c])) {
		my ($lane, $tile, $cycle) = ($f[$c], $f[$c+1], $f[$c+2]);
		$c += 3;					# Phase 3 fields over
		my $j = 0;
		while ($j < 50) {
			my $qBin = ($j+1);
			my $numClusters = $f[$c+$j];
    
      my $query =	"INSERT INTO MiSeqQC_QualityMetrics " .
        "(RunID, lane, tile, cycle, Q_bin, numClusters) VALUES " .
        "('$RunID', '$lane', '$tile', '$cycle', '$qBin', '$numClusters')";

                my $sth = $db->prepare($query); $sth->execute();

			$j++;
			if ($count % 25000 == 0) { my @t = localtime(time); my $time = "$t[2]:$t[1]:$t[0]";  print "[$time] $RunID - QualityMetrics, record $count\n"; }
			$count++;
			}
		$c+= 50;						# Phase 50 fields over
		}
	close(INPUT);						# File is large - close gracefully
	undef $line;						# Variable is large - clear gracefully

	$db->commit();
	print "Committed transaction for QualityMetrics!\n\n";
}

1;
