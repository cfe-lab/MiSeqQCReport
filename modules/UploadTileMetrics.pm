# tileMetricsOut.bin
#
# Byte 0: File version
# Byte 1: Length of each record
#
# Followed by repeated 4-field, 10-byte structure:
#
# 2 bytes: lane					[uint16]
# 2 bytes: tile 				[uint16]
# 2 bytes: metric code			[uint16]
# 4 bytes: metric value		  	[float]
#
# Tile metric codes
#
# 100: cluster density (k/mm^2)
# 101: cluster density passing filters (k/mm^2)
# 102: number of clusters
# 103: number of clusters passing filters (k/mm^2)
#
# 200+2*(N-1) - phasing
# N=1 200, N=2 202, N=3 204, N=4 206
#
# 201+2*(N-1) - prephasing
# N=1 201, N=2 203, N=3 205, N=4 207
#
# 300+(N-1) - percent aligned
# N=1 300, N=2 301, N=3 302, N=4 303

use strict;
use DBI;
use DBD::Oracle;

sub uploadTileMetrics($$$) {

        my ($RunID, $binFile, $db) = @_;
	open(INPUT, $binFile) || die "Couldn't open $binFile";

	local $/;											# Slurp mode: 	Prevent incorrect newline interpretation of binary data
	my $line = <INPUT>;

	my @f = unpack("cc(SSSf)*", $line);					# c: signed char [1 byte]

	my ($fileVersion, $numRecords) = ($f[0], $f[1]);	# S: unsigned short (uint16) [2 bytes]
														# f: single precision float [4 bytes]
	my $c = 2;
	my $count = 1;
	while (defined($f[$c])) {
		my ($lane, $tile, $tileMetricCode, $tileMetricValue) = ($f[$c], $f[$c+1], $f[$c+2], $f[$c+3], $f[$c+4]);
		if ($tileMetricCode =~ m/^400$/) { $c += 4; next; }

        my $query = q{
            INSERT
            INTO    MiSeqQC_TileMetrics
                    (
                    RunID,
                    lane,
                    tile,
                    metricCode,
                    value
                    )
            VALUES (?, ?, ?, ?, ?)
        };

        my $sth = $db->prepare($query);
        $sth->execute(
            $RunID,
            $lane,
            $tile,
            $tileMetricCode,
            $tileMetricValue);
		if ($count % 100 == 0) { my @t = localtime(time); my $time = "$t[2]:$t[1]:$t[0]";  print "[$time] $RunID - TileMetrics, Record $count\n"; }
		$c += 4;
		$count++;
	}

	$db->commit();
	print "Committed transaction for TileMetrics!\n\n";
	close(INPUT);						# File is large - close gracefully
	undef $line;						# Variable is large - clear gracefully
}

1;
