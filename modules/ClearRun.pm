# Completely deletes this run from the Oracle database

sub clear_run {
    if (scalar(@_) != 1) { die "Correct syntax: clear_run(RunID)"; }
    my ($runID) = @_;

	use DBI;
	require "/home/emartin/QC_InterOp_Upload/scriptDependencies/setup_oracle_authentication.pl";
	my ($env_oracle_home, $host, $port, $sid, $user, $password) = activateOracle();
	$ENV{ORACLE_HOME} = $env_oracle_home;
	my $db=DBI->connect("dbi:Oracle:host=$host;sid=$sid;port=$port", $user, $password, {PrintError => 0, PrintWarn => 1, AutoCommit => 0});

	my @tables = (	"correctedintensities", "errormetrics", "extractionmetrics", "tilemetrics",
					"qualitymetrics", "extractionmetrics", "interopsummary", "runparameters");

	foreach my $table (@tables) {
		my $query = "DELETE FROM SPECIMEN.miseqqc_$table WHERE runID='$runID'";
		print "$query\n";

		my $sth = $db->prepare($query);
		$sth->execute();
		if ( $sth->err ) {
			print "\nERROR! ROLLING BACK TRANSACTION...\n\nError msg: " . $sth->errstr . "\n\n";
			$db->rollback();
			$db->disconnect();
			die '';
			}
		$sth->finish;
		}
	$db->commit();
	print "Committed transaction for clearing run $runID!\n\n";
	$db->disconnect();
	}
1;
