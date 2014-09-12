# ErrorMetricsOut.bin stores PhiX error
#
# Byte 0: File version
# Byte 1: Length of each record
#
# Followed by a repeated 30-byte structure:
#
# 2 bytes: lane							[uint16]
# 2 bytes: tile 						[uint16]
# 2 bytes: cycle 						[uint16]
# 4 bytes: error rate 					[float]
# 4 bytes: numPerfectReads 				[uint32]
# 4*4 bytes: reads with 1,2,3,4 errors 	[uint32]

use DBI;
use DBD::Oracle;

sub uploadErrorMetrics {

	if (scalar(@_) != 2) { die "Correct syntax: uploadErrorMetrics(RunID, binFile)"; }
	my ($RunID, $binFile, $debug) = @_;
	open(INPUT, $binFile) || die "Couldn't open $binFile";

	require "/path/to/source/QC_InterOp_Upload/scriptDependencies/setup_oracle_authentication.pl";
	my ($env_oracle_home, $host, $port, $sid, $user, $password) = activateOracle();
	$ENV{ORACLE_HOME} = $env_oracle_home;
	use DBI;
	my $db=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $password, {PrintError => 0, PrintWarn => 1, AutoCommit => 0});

	local $/;											# Slurp mode: Prevent incorrect newline interpretation of binary data
	my $line = <INPUT>;

	my @f = unpack("cc(SSSfVVVVV)*", $line);			# c: signed char [1 byte]		# f: single precision float [4 bytes]
	my ($fileVersion, $numRecords) = ($f[0], $f[1]);	# S: unsigned short [2 bytes]	# V: unsigned long [4 bytes]
	my $return = "";

	$c = 2;
	$count = 1;
	while (defined($f[$c])) {
		my 	($lane, $tile, $cycle, $errorRate, $perfectReads, $err1, $err2, $err3, $err4) =
			($f[$c], $f[$c+1], $f[$c+2],$f[$c+3],$f[$c+4],$f[$c+5],$f[$c+6],$f[$c+7], $f[$c+8]);

		$errorRate = sprintf("%.4f", $errorRate);

		my $query =     "INSERT INTO specimen.MiSeqQC_ErrorMetrics " .
						"(RunID, lane, tile, cycle, " .
						"errorRate, numPerfectReads, numReadsOneError, numReadsTwoError, numReadsThreeError, numReadsFourError) VALUES " .
						"('$RunID', '$lane', '$tile', '$cycle', " .
						" '$errorRate', '$perfectReads', '$err1', '$err2', '$err3', '$err4')";

		my $sth = $db->prepare($query); $sth->execute();
		if ( $sth->err ) {
			print "\nERROR! ROLLING BACK TRANSACTION...\n\nError msg: " . $sth->errstr . "\n\n";
			$db->rollback();
			$db->disconnect();
			die;
			}

		if ($count % 2500 == 0) { @t = localtime(time); $time = "$t[2]:$t[1]:$t[0]";  print "[$time] $RunID - ErrorMetrics, record $count\n"; }
		$count++;
		$c+= 9;
		}
	close(INPUT);
	undef $line;
	$db->commit();
	print "Committed transaction for CorrectedIntensityMetrics!\n\n";
	$db->disconnect();
	}
1;
