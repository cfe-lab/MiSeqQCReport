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

use DBI;
use DBD::Oracle;

sub uploadQualityMetrics {
	if (scalar(@_) != 2) { die "Correct syntax: uploadQualityMetrics(RunID, binFile)"; }
	my ($RunID, $binFile) = @_;
	open(INPUT, $binFile) || die "Couldn't open $binFile";

	require "/path/to/source/QC_InterOp_Upload/scriptDependencies/setup_oracle_authentication.pl";
	my ($env_oracle_home, $host, $port, $sid, $user, $password) = activateOracle();
	$ENV{ORACLE_HOME} = $env_oracle_home;
	use DBI;
	my $db=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $password, {PrintError => 0, PrintWarn => 1, AutoCommit => 0});

	local $/;							# Slurp mode: 	Prevent incorrect newline interpretation of binary data
	my $line = <INPUT>;					#				Loads entire contents of file at once

	my @f = unpack("cc(SSSV50)*", $line);				# c: signed char [1 byte]
	my ($fileVersion, $numRecords) = ($f[0], $f[1]);	# S: unsigned short (uint16) [2 bytes]
														# V: unsigned long (uint32) [4 bytes]
	$c = 2;
	my $count = 1;
	while (defined($f[$c])) {
		my ($lane, $tile, $cycle) = ($f[$c], $f[$c+1], $f[$c+2]);
		$c += 3;					# Phase 3 fields over
		$j = 0;
		while ($j < 50) {
			$qBin = ($j+1);
			$numClusters = $f[$c+$j];
    
      my $query =	"INSERT INTO specimen.MiSeqQC_QualityMetrics " .
        "(RunID, lane, tile, cycle, Q_bin, numClusters) VALUES " .
        "('$RunID', '$lane', '$tile', '$cycle', '$qBin', '$numClusters')";

                my $sth = $db->prepare($query); $sth->execute();
      if ( $sth->err ) {
        print "\nERROR! ROLLING BACK TRANSACTION...\n\nError msg: " . $sth->errstr . "\n\n";
        $db->rollback();
        $db->disconnect();
        die '';
      }
    

			$j++;
			if ($count % 25000 == 0) { @t = localtime(time); $time = "$t[2]:$t[1]:$t[0]";  print "[$time] $RunID - QualityMetrics, record $count\n"; }
			$count++;
			}
		$c+= 50;						# Phase 50 fields over
		}
	close(INPUT);						# File is large - close gracefully
	undef $line;						# Variable is large - clear gracefully

	$db->commit();
	print "Committed transaction for QualityMetrics!\n\n";
	$db->disconnect();
	}
1;
