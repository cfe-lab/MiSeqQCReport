#!/usr/bin/perl -w

# Query the database for raw quality data and generates summary values for rapid retrieval / monthly reports

use strict;
    
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
    
sub getReadBounds($$$$) {
    my ($read1_L, $index1_L, $index2_L, $read2_L) = @_;
    my $read1_bound = $read1_L;
    my $read2_bound = $read1_bound+$index1_L;
    my $read3_bound = $read2_bound+$index2_L;
    my $read4_bound = $read3_bound+$read2_L;
    return ($read1_bound, $read2_bound, $read3_bound, $read4_bound);
}

sub uploadSummaryValues($$) {
    my ($RunID, $db) = @_;

    # Don't allow % or else this will screw SQL queries
    $RunID =~ s/[%]//g;

    my $query = "SELECT * FROM MiSeqQC_interopsummary WHERE runID LIKE '$RunID'";
    my $sth = $db->prepare($query);
    $sth->execute();
    if ($sth->fetchrow_array()) {
    	$sth->finish();
    	die "RunID $RunID already has interopsummary data";
   	}

    # Get the read/index length information so we can create filters on the quality data to look at read 1 vs read 2
    print "\nGetting read/index length information...\n";
    $query = "SELECT read1, index1, index2, read2 FROM MiSeqQC_RunParameters WHERE runID LIKE '$RunID'";
    $sth = $db->prepare($query); $sth->execute();
    my ($read1, $index1, $index2, $read2);
    if (my @row = $sth->fetchrow_array()) {
        ($read1, $index1, $index2, $read2) = @row;
        $sth->finish();
    }
    else {
    	$sth->finish();

    	die	"Run id $RunID doesn't appear to exist.";
   	}

    my ($bound1, $bound2, $bound3, $bound4) = getReadBounds($read1,$index1,$index2,$read2);
    $read1 = "cycle > 0 AND cycle <= $bound1";
    $index1 = "cycle > $bound1 AND cycle <= $bound2";	# indexLength = 0 generates a null restriction
    $index2 = "cycle > $bound2 AND cycle <= $bound3";
    $read2 = "cycle > $bound3 AND cycle <= $bound4";

    # Aligned: Get the percent aligned (???) (Code 300 for read 1, code 303 for read 4) across all tiles
    my ($aligned_L, $aligned_R, $percentPerfectClusters_1, $percentPerfectClusters_2);
    print "Getting percent aligned...\n";
    my $metricCode = 300;

    # % Aligned for read 1
    $query = 	"SELECT AVG(Value) aligned FROM MiSeqQC_TileMetrics " .
    			"WHERE runID LIKE '$RunID' AND metricCode LIKE '$metricCode'"; $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { $aligned_L = $row[0]; } else { die "Could not retrieve % PhiX (Metric: $metricCode)"; } $sth->finish();

    if ($bound1 == $bound2) { $metricCode += 1; }	# Non-indexed -> read 2 = 301 
    else { $metricCode += 3; }			# Dual-indexed -> read 2 = 303

    # % Aligned for read 2
    $query = 	"SELECT AVG(Value) aligned FROM MiSeqQC_TileMetrics " .
    			"WHERE runID LIKE '$RunID' AND metricCode LIKE '$metricCode'"; $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { $aligned_R = $row[0]; } else { die "Could not retrieve % PhiX (Metric: $metricCode)"; } $sth->finish();
    $aligned_L = sprintf("%.3f", $aligned_L); $aligned_R = sprintf("%.3f", $aligned_R);





    # Get the raw intensity values
    my ( $A_1_1, $C_1_1, $G_1_1, $T_1_1, $A_1_20, $C_1_20, $G_1_20, $T_1_20, $A_2_1, $C_2_1, $G_2_1, $T_2_1, $A_2_20, $C_2_20, $G_2_20, $T_2_20);
    print "Getting raw intensity values...\n";

    # Intensity (Read 1, Cycle 1, avg over tiles)
    $query = 	"SELECT AVG(INTENSITY_A), AVG(INTENSITY_C), AVG(INTENSITY_G), AVG(INTENSITY_T) FROM MiSeqQC_ExtractionMetrics " .
    			"WHERE RunID LIKE '$RunID' AND cycle IN " .
    			"(SELECT MIN(cycle) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND $read1)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($A_1_1, $C_1_1, $G_1_1, $T_1_1) = @row; } else { die "Could not retrieve intensity"; } $sth->finish();
    $A_1_1 = sprintf("%.2f", $A_1_1); $C_1_1 = sprintf("%.2f", $C_1_1); $G_1_1 = sprintf("%.2f", $G_1_1); $T_1_1 = sprintf("%.2f", $T_1_1);

    # Intensity (Read 1, Cycle 20, avg over tiles)
    $query =	"SELECT AVG(INTENSITY_A), AVG(INTENSITY_C), AVG(INTENSITY_G), AVG(INTENSITY_T) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND cycle IN " .
    			"19 + (SELECT MIN(cycle) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND $read1)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($A_1_20, $C_1_20, $G_1_20, $T_1_20) = @row; } else { die "Could not retrieve intensity"; } $sth->finish();
    $A_1_20 = sprintf("%.2f", $A_1_20); $C_1_20 = sprintf("%.2f", $C_1_20); $G_1_20 = sprintf("%.2f", $G_1_20); $T_1_20 = sprintf("%.2f", $T_1_20);

    # Intensity (Read 2, Cycle 1 avg over tiles)
    $query =	"SELECT AVG(INTENSITY_A), AVG(INTENSITY_C), AVG(INTENSITY_G), AVG(INTENSITY_T) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND cycle IN " .
    		"(SELECT MIN(cycle) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND $read2)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($A_2_1, $C_2_1, $G_2_1, $T_2_1) = @row; } else { die "Could not retrieve intensity"; } $sth->finish();
    $A_2_1 = sprintf("%.2f", $A_2_1); $C_2_1 = sprintf("%.2f", $C_2_1); $G_2_1 = sprintf("%.2f", $G_2_1); $T_2_1 = sprintf("%.2f", $T_2_1);

    # Intensity (Read 2, Cycle 20 avg over tiles)
    $query =	"SELECT AVG(INTENSITY_A), AVG(INTENSITY_C), AVG(INTENSITY_G), AVG(INTENSITY_T) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND cycle IN " .
    		"19 + (SELECT MIN(cycle) FROM MiSeqQC_ExtractionMetrics WHERE RunID LIKE '$RunID' AND $read2)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($A_2_20, $C_2_20, $G_2_20, $T_2_20) = @row; } else { die "Could not retrieve intensity"; } $sth->finish();
    $A_2_20 = sprintf("%.2f", $A_2_20); $C_2_20 = sprintf("%.2f", $C_2_20);	$G_2_20 = sprintf("%.2f", $G_2_20); $T_2_20 = sprintf("%.2f", $T_2_20);



    # Determine the percent of clusters >= Q30
    my ($Q_less_30_1, $Q_less_30_2, $Q_greater_30_1, $Q_greater_30_2);
    print "Getting % cluster > Q30...\n";

    # Read 1
    $query = "SELECT SUM(numClusters) FROM MiSeqQC_QualityMetrics WHERE RunID LIKE '$RunID' AND $read1 AND Q_Bin < 30"; $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($Q_less_30_1) = @row; } else { die "Could not retrieve quality metrics"; } $sth->finish();
    $query = "SELECT SUM(numClusters) FROM MiSeqQC_QualityMetrics WHERE RunID LIKE '$RunID' AND $read1 AND Q_Bin >= 30"; $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($Q_greater_30_1) = @row; } else { die "Could not retrieve quality metrics"; } $sth->finish();
    my $proportion_Q_30_1 = sprintf("%.2f", $Q_greater_30_1 / ($Q_less_30_1 + $Q_greater_30_1));

    # Read 2
    $query = "SELECT SUM(numClusters) FROM MiSeqQC_QualityMetrics WHERE RunID LIKE '$RunID' AND $read2 AND Q_Bin < 30"; $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($Q_less_30_2) = @row; } else { die "Could not retrieve quality metrics"; } $sth->finish();
    $query = "SELECT SUM(numClusters) FROM MiSeqQC_QualityMetrics WHERE RunID LIKE '$RunID' AND $read2 AND Q_Bin >= 30"; $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($Q_greater_30_2) = @row; } else { die "Could not retrieve quality metrics"; } $sth->finish();
    my $proportion_Q_30_2 = sprintf("%.2f", $Q_greater_30_2 / ($Q_less_30_2 + $Q_greater_30_2));


    # Determine the cluster / cluster density, and the amount passing chastity filtering
    my ($clusterDensity, $clusters, $clustersPF, $percentPF);
    print "Getting cluster density...\n";

    # Cluster density (k/mm^2) - averaged across tiles
    $query = "SELECT AVG(value) FROM MiSeqQC_TileMetrics WHERE runID LIKE '$RunID' AND metricCode LIKE '100'";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($clusterDensity) = @row; } else { die "Could not retrieve cluster density"; } $sth->finish();
    $clusterDensity = sprintf("%.2f", $clusterDensity/1000);

    # Clusters - summed across tiles
    $query = "SELECT SUM(value) FROM MiSeqQC_TileMetrics WHERE runID LIKE '$RunID' AND metricCode LIKE '102'";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($clusters) = @row; } else { die "Could not retrieve clusters"; } $sth->finish();

    # Clusters passing filter - summed across tiles
    $query = "SELECT SUM(value) FROM MiSeqQC_TileMetrics WHERE runID LIKE '$RunID' AND metricCode LIKE '103'";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($clustersPF) = @row; } else { die "Could not retrieve clusters"; } $sth->finish();
    my $cluster_percentPF = sprintf("%.2f", $clustersPF / $clusters * 100);




    # Phasing and pre-phasing for reads 1/2
    my ($phase_1, $phase_2, $prephase_1, $prephase_2);
    print "Getting phasing/prephasing...\n";

    # Phasing (Even numbered 200 metricCodes) - for the forward read, take the min metricCode, and average over tiles
    $query =	"SELECT ROUND(AVG(value)*100,3) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode IN " .
    		"(SELECT MIN(metricCode) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode LIKE '20%' AND MOD(metricCode,2) = 0)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($phase_1) = @row; } else { die "Could not retrieve phase_1"; } $sth->finish();

    # Phasing (Even numbered 200 metricCodes) - for the reverse read, take the max metricCode, and average over tiles
    $query =	"SELECT ROUND(AVG(value)*100,3) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode IN " .
    		"(SELECT MAX(metricCode) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode LIKE '20%' AND MOD(metricCode,2) = 0)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($phase_2) = @row; } else { die "Could not retrieve phase_2"; } $sth->finish();

    # Prephasing (Odd numbered 200 metricCodes) - for the forward read, take the min metricCode, and average over tiles
    $query =        "SELECT ROUND(AVG(value)*100,3) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode IN " .
                    "(SELECT MIN(metricCode) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode LIKE '20%' AND MOD(metricCode,2) = 1)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($prephase_1) = @row; } else { die "Could not retrieve phase_1"; } $sth->finish();

    # Prephasing (Odd numbered 200 metricCodes) - for the reverse read, take the max metricCode, and average over the tiles
    $query =        "SELECT ROUND(AVG(value)*100,3) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode IN " .
                    "(SELECT MAX(metricCode) FROM MiSeqQC_TileMetrics WHERE RunID LIKE '$RunID' AND metricCode LIKE '20%' AND MOD(metricCode,2) = 1)";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($prephase_2) = @row; } else { die "Could not retrieve phase_2"; } $sth->finish();




    # Determine the ErrorRate (as determined by PhiX alignment)
    #	1) numPerfectReads: a cumulative value - decreases with respect to cycle
    # 	2) Total reads (0 error + 1 error + 2 error + 3 error + 4 error) is roughly the same, but drifts up and down a little bit

    my ($error_1_35, $error_2_35);
    print "Getting errorRate...\n";

    # Error rate (Cycle 1-35) - read 1
    my $read_1_cycle_35 = 35;
    $query = "SELECT 1-(SUM(numPerfectReads) / SUM(numPerfectReads+numreadsoneerror+numreadstwoerror+numreadsthreeerror+numreadsfourerror)) errorRate, cycle " .
    	 "FROM MiSeqQC_ErrorMetrics WHERE runID LIKE '$RunID' AND cycle = $read_1_cycle_35 GROUP BY cycle ORDER BY cycle";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($error_1_35) = @row; } else { die "Could not retrieve phase_2"; } $sth->finish();
    $error_1_35 = sprintf("%.3f", $error_1_35);

    # Error rate (Cycle 1-35) - read 2
    my $read_2_cycle_35 = $bound3 + 35;
    $query = "SELECT 1-(SUM(numPerfectReads) / SUM(numPerfectReads+numreadsoneerror+numreadstwoerror+numreadsthreeerror+numreadsfourerror)) errorRate, cycle " .
             "FROM MiSeqQC_ErrorMetrics WHERE runID LIKE '$RunID' AND cycle = $read_2_cycle_35 GROUP BY cycle ORDER BY cycle";
    $sth = $db->prepare($query); $sth->execute();
    if (my @row = $sth->fetchrow_array()) { ($error_2_35) = @row; } else { die "Could not retrieve phase_2"; } $sth->finish();
    $error_2_35 = sprintf("%.3f", $error_2_35);


    # Display the results to the screen
    print	"\nRESULTS: $RunID\n" .
    	"% aligned (Read 1)\t$aligned_L (VALIDATED)\n" .
    	"% aligned (Read 2)\t$aligned_R (VALIDATED)\n" .
    	"Intensity (Read 1, Cycle 1)\t$A_1_1\t$C_1_1\t$G_1_1\t$T_1_1\n" .
    	"Intensity (Read 1, Cycle 20)\t$A_1_20\t$C_1_20\t$G_1_20\t$T_1_20\n" .
    	"Intensity (Read 2, Cycle 1)\t$A_2_1\t$C_2_1\t$G_2_1\t$T_2_1\n" .
    	"Intensity (Read 2, Cycle 20)\t$A_2_20\t$C_2_20\t$G_2_20\t$T_2_20\n" .
    	"Proportion > Q30 (Read 1)\t$proportion_Q_30_1 (VALIDATED)\n" .
    	"Proportion > Q30 (Read 2)\t$proportion_Q_30_2 (VALIDATED)\n" .
    	"Density\t$clusterDensity (VALIDATED)\n" .
    	"% clusters PF\t$cluster_percentPF (VALIDATED)\n" .
    	"Phase (Read 1)\t$phase_1 (VALIDATED)\n" .
    	"Phase (Read 2)\t$phase_2 (VALIDATED)\n" .
    	"Prephase (Read 1)\t$prephase_1 (VALIDATED)\n" .
    	"Prephase (Read 2)\t$prephase_2 (VALIDATED)\n" .
    	"Error rate (Read 1, Cycle 35)\t$error_1_35\n" .
    	"Error rate (Read 2, Cycle 35)\t$error_2_35\n";

    print "\nUploading summary data...\n";

    # Upload summary values to the database
    $query = 	"INSERT INTO MiSeqQC_InterOpSummary " .
    			"(runID, aligned_F, aligned_R, " .
    			"int_1_1_A,  int_1_1_C,  int_1_1_G,  int_1_1_T, " .
    			"int_1_20_A, int_1_20_C, int_1_20_G, int_1_20_T, " .
    			"int_2_1_A,  int_2_1_C,  int_2_1_G,  int_2_1_T, " .
    			"int_2_20_A, int_2_20_C, int_2_20_G, int_2_20_T, " .
    			"Q30_1, Q30_2, clusterDensity, percentClustersPF, phasing_F, phasing_R, prephasing_F, prephasing_R, errorRate_F, errorRate_R) VALUES " .
    			"('$RunID', '$aligned_L', '$aligned_R', " .
    			"'$A_1_1',  '$C_1_1',  '$G_1_1',  '$T_1_1', " .
    			"'$A_1_20', '$C_1_20', '$G_1_20', '$T_1_20', " .
    			"'$A_2_1',  '$C_2_1',  '$G_2_1',  '$T_2_1', " .
    			"'$A_2_20', '$C_2_20', '$G_2_20', '$T_2_20', " .
    			"'$proportion_Q_30_1', '$proportion_Q_30_2', '$clusterDensity', '$cluster_percentPF', " .
    			"'$phase_1', '$phase_2', '$prephase_1', '$prephase_2', '$error_1_35', '$error_2_35')";

    $sth = $db->prepare($query);
    $sth->execute();
    $sth->finish();
    $db->commit();    

    #We don't need this data any more, so let's get rid of it.
    $query = "delete from MiSeqQC_QualityMetrics where cycle not in (50, 260,500)";
    $sth = $db->prepare($query);
    $sth->execute();
    $sth->finish();
    $db->commit();
}

1;
