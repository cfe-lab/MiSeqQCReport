#!/usr/bin/perl -w

# Looks for runs ready to be processed and upload their interop QC data into the Oracle database.

use strict;
use File::Basename;
use File::Path qw(make_path remove_tree);

use Settings;
use lib 'modules';
use ExtractConanDateFromSamplesheet;
use UploadCorrectedIntensityMetrics;
use UploadErrorMetrics;
use UploadExtractionMetrics;
use UploadQualityMetrics;
use UploadRunParameters;
use UploadSummaryValues;
use UploadTileMetrics;

my $settings = new Settings();

my $miseq_data   = $settings->{'raw_data_path'};    #  Where to check MiSeq runs
my $write_folder = "upload_working";                # Local storage
my ( $needs_processing, $qc_complete, $qc_failure ) =
  ( 'needsprocessing', 'qc_uploaded', 'qc_failed_to_upload' );

# Write message to failure file, and complain to stdout.
sub failRun($$) {
    my ($error_message, $error_file_name) = @_;
    open( my $error_file, '>', $error_file_name )
      or die "Could not open error file '$error_file_name'.";
    print $error_file "$error_message\n";
    my ($package, $filename, $line) = caller;
    my $details = "Error occurred in $package:$filename line $line.";
    print $error_file "$details\n";
    close $error_file;
    
    print "$error_message\n";
    print "$details\n";
}

# Run several commands, and return 1 if they all succeed. If one fails,
# mark the run as failed and return 0.
sub runCommands($@) {
    my ($qc_failure_file, @commands) = @_;
    foreach my $command (@commands) {
        if (system($command) != 0) {
            die "Couldn't run '$command'.";
        }
    }
}

sub verifyInputFiles($$@) {
    my ($qc_failure_file, $working_folder, @paths) = @_;
    foreach my $subpath (@paths) {
        if ( ! (-e "$working_folder/$subpath")) {
            die "Input file '$working_folder/$subpath' not found.";
        }
    }
}

# Process all the data files for a run, die if anything goes wrong.
sub processRun($$$) {
    my ($path, $write_folder, $dbh) = @_;

    if ( !( -d "$path/InterOp" ) ) {
        die "$path/InterOp not found."
    }

    my $new_folder = "$write_folder/" . basename($path);
    make_path($new_folder);
    remove_tree( $new_folder, { keep_root => 1 } );

    # Copy the necessary files
    runCommands(
        "$path/$qc_failure",
        "cp -r $path/InterOp $new_folder/",
        "cp $path/SampleSheet.csv $new_folder/",
        "cp $path/[rR]unParameters.xml $new_folder/runParameters.xml",
        "cp $path/RunInfo.xml $new_folder/");

    verifyInputFiles(
        "$path/$qc_failure",
        $new_folder,
        "InterOp/CorrectedIntMetricsOut.bin",
        "InterOp/ErrorMetricsOut.bin",
        "InterOp/ExtractionMetricsOut.bin",
        "InterOp/QMetricsOut.bin",
        "InterOp/TileMetricsOut.bin");

    # Get Conan's SampleSheet creator date, upload the QC data, link them to that date
    my $samplesheet_date = getSampleSheetDate($new_folder);
    my $RunID = uploadRunParameters(
        "$new_folder/runParameters.xml",
        $samplesheet_date,
        $dbh );
    uploadCorrectedIntensityMetrics(
        $RunID,
        "$new_folder/InterOp/CorrectedIntMetricsOut.bin",
        $dbh);
    uploadErrorMetrics(
        $RunID,
        "$new_folder/InterOp/ErrorMetricsOut.bin",
        $dbh);
    uploadExtractionMetrics(
        $RunID,
        "$new_folder/InterOp/ExtractionMetricsOut.bin",
        $dbh);
    uploadQualityMetrics($RunID, "$new_folder/InterOp/QMetricsOut.bin", $dbh);
    uploadTileMetrics($RunID, "$new_folder/InterOp/TileMetricsOut.bin", $dbh);
    uploadSummaryValues($RunID, $dbh);
}

my $success_count = 0;
my $failure_count = 0;
$ENV{ORACLE_HOME} = $settings->{'env_oracle_home'};
my $dbh=DBI->connect(
    "dbi:Oracle:host=$settings->{'host'};sid=$settings->{'sid'};port=$settings->{'port'}", 
    $settings->{'user'},
    $settings->{'password'},
    {RaiseError => 1, PrintError => 0, PrintWarn => 1, AutoCommit => 0});

my @glob = <$miseq_data/*>;
foreach my $path (@glob) {
    if ( !( -d $path ) ) { next; }                  # For folders in macdatafile
    if ( !( -e "$path/$needs_processing" ) ) {
        next;
    }    # Which are marked for processing
    if ( ( -e "$path/$qc_complete" ) || ( -e "$path/$qc_failure" ) ) {
        next;
    }    # And has not already had QC uploaded
    
    eval {
        processRun($path, $write_folder, $dbh);
        
        # If the upload was successful, write a qc_complete file flag on macdatafile
        open( QC_PASSED, ">$path/$qc_complete" );
        close(QC_PASSED);
        $success_count += 1;
    };
    if ($@) {
        my $error_message = $@;
        print "Run $path failed: $error_message";
        $failure_count += 1;
        
        $dbh->rollback();
        my $error_file_name = "$path/$qc_failure";
        open( my $error_file, '>', $error_file_name )
          or die "Could not open error file '$error_file_name'.";
        print $error_file "$error_message\n";
        close $error_file;
    }
}

$dbh->disconnect();
print "Finished with $success_count successes and $failure_count failures.";
