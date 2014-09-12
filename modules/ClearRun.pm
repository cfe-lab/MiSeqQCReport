# Completely deletes this run from the Oracle database

use strict;

sub clearRun($$) {
    my ($runID, $db) = @_;
    
    my $query_for_complete_run = q{
        SELECT  COUNT(1)
        FROM    MiSeqQC_InteropSummary
        WHERE   runid = ?
    };
    my $sth = $db->prepare($query_for_complete_run);
    $sth->execute($runID);
    my $match_count = $sth->fetchrow_array();
    $sth->finish();
    if ($match_count > 0) {
        die "Run id $runID is already in the database and complete."
    }
    
	my @tables = (
        "CORRECTEDINTENSITIES",
        "ERRORMETRICS",
        "EXTRACTIONMETRICS",
        "TILEMETRICS",
		"QUALITYMETRICS",
		"EXTRACTIONMETRICS",
		"RUNPARAMETERS");

	foreach my $table (@tables) {
	    my $quoted_tablename = $db->quote_identifier("MISEQQC_$table");
		my $query = "DELETE FROM $quoted_tablename WHERE runID = ?";

		my $sth = $db->prepare($query);
		$sth->execute($runID);
		$match_count += $sth->rows;
		$sth->finish;
	}
	$db->commit();
	
	if ($match_count > 0) {
    	print "Cleared $match_count existing records from run $runID.\n";
	}
}

1;
