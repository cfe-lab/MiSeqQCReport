sub uploadRunParameters {
	if (scalar(@_) != 2) { die 'Correct syntax: uploadRunParameters("folder/runParams.xml", "2013-01-01")'; }
	my ($filePath, $samplesheet_date, $debug) = @_;

	use XML::Simple;
	my $xml = new XML::Simple;

	require "/path/to/source/QC_InterOp_Upload/scriptDependencies/setup_oracle_authentication.pl";
	my ($env_oracle_home, $host, $port, $sid, $user, $password) = activateOracle();
	$ENV{ORACLE_HOME} = $env_oracle_home;
	use DBI;
	my $db=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $password, {PrintError => 0, PrintWarn => 1, AutoCommit => 0});

	my $data = $xml->XMLin("$filePath");
	my %tags = %{$data};

	my ($RunID, $Username, $ExperimentName, $RunStartDate) = ($tags{'RunID'}, $tags{'Username'}, $tags{'ExperimentName'}, $tags{'RunStartDate'});

	my (%flowCellTags) =  (%{$tags{'FlowcellRFIDTag'}});
	my ($flowCellSerial, $flowCellPart, $flowCellExpiration) = ($flowCellTags{'SerialNumber'}, $flowCellTags{'PartNumber'}, $flowCellTags{'ExpirationDate'});
	$flowCellExpiration = substr($flowCellExpiration,2,2) . substr($flowCellExpiration,5,2) . substr($flowCellExpiration,8,2);

	my %PR2Tags =  %{$tags{'PR2BottleRFIDTag'}};
	my ($PR2Serial, $PR2Part, $PR2Expiration) = ($PR2Tags{'SerialNumber'}, $PR2Tags{'PartNumber'}, $PR2Tags{'ExpirationDate'});
	$PR2Expiration = substr($PR2Expiration,2,2) . substr($PR2Expiration,5,2) . substr($PR2Expiration,8,2);

	my %ReagentKitTags =  %{$tags{'ReagentKitRFIDTag'}};
	my ($reagentSerial, $reagentPart, $reagentExpiration) = ($ReagentKitTags{'SerialNumber'}, $ReagentKitTags{'PartNumber'}, $ReagentKitTags{'ExpirationDate'});
	$reagentExpiration = substr($reagentExpiration,2,2) . substr($reagentExpiration,5,2) . substr($reagentExpiration,8,2);

	my ($MCSVersion, $RTAVersion, $FPGAVersion) = ($tags{'MCSVersion'}, $tags{'RTAVersion'}, $tags{'FPGAVersion'});

	# Get the read lengths
	my @runInfoReads = @{$tags{'Reads'}->{'RunInfoRead'}};
	my ($readLength1, $indexLength1, $indexLength2, $readLength2);
	if (scalar(@runInfoReads) != 4) { die 'Missing run length data'; }
	$read1 = $runInfoReads[0]->{'NumCycles'};
	$index1 = $runInfoReads[1]->{'NumCycles'};
	$index2 = $runInfoReads[2]->{'NumCycles'};
	$read2 = $runInfoReads[3]->{'NumCycles'};

	my $query =	"SELECT * FROM specimen.MiSeqQC_RunParameters WHERE runID LIKE '$RunID'";
	my $sth = $db->prepare($query);
	$sth->execute();

	if ($sth->fetchrow_array()) { die "uploadRunParameters.pl: RunID $RunID has already been uploaded into the database"; }

	$query = 	"INSERT INTO specimen.MiSeqQC_RunParameters " .
				"(runID, username, experimentName, runStartDate, " .
				"flowcell_serial, flowcell_part_number, flowcell_expiration, PR2_serial, PR2_part_number, PR2_expiration, " .
				"reagentKit_serial, reagentKit_part_number, reagentKit_expiration, MCS_version, RTA_version, FPGA_version, " .
				"read1, index1, index2, read2, sample_sheet_date) VALUES" .
				"('$RunID', '$Username', '$ExperimentName', to_date('$RunStartDate', 'YYMMDD'), " .
				"'$flowCellSerial', '$flowCellPart', to_date('$flowCellExpiration', 'YYMMDD'), '$PR2Serial', '$PR2Part', to_date('$PR2Expiration', 'YYMMDD'), " .
				"'$reagentSerial', '$reagentPart', to_date('$reagentExpiration', 'YYMMDD'), '$MCSVersion', '$RTAVersion', '$FPGAVersion', " .
				"'$read1', '$index1', '$index2', '$read2', to_date('$samplesheet_date','YYYY-MM-DD'))";

	$sth = $db->prepare($query);
	$sth->execute();

	if ( $sth->err ) {
		print "\nERROR! ROLLING BACK TRANSACTION...\n\nError msg: " . $sth->errstr . "\n\n";
		$db->rollback();
		$db->disconnect();
		print "ATTEMPTING TO RUN CLEAR_RUN($RunID) ...";
		require '/Users/emartin/Desktop/MiSeq/QC_InterOp_Upload/scriptDependencies/clear_run.pl';
		clear_run($RunID);	
		die;
		}

	$db->commit();
	$db->disconnect();

	@t = localtime(time); $time = "$t[2]:$t[1]:$t[0]";
	print "\n[$time] $RunID - Uploaded: RunParameters ($read1,$index1,$index2,$read2)\n";
	print "Committed transaction for RunParameters!\n\n";
	return ($RunID);
	}

1;