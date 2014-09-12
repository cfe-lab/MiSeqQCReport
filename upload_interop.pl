#!/usr/bin/perl

# Uploads the interop data of a run into the Oracle database
use strict;
use DBI;
use DBD::Oracle;

my $root = "/path/to/source/QC_InterOp_Upload";
my $dependencyFolder = "$root/scriptDependencies";
chdir($root);

# Check that a path is given, and that within that path, the correct files are present
if (scalar(@ARGV) != 1) { die "\nSyntax: $0 /runs/Example_130621_M01841_0006_000000000-A3RWC"; }
my $folderPath = $ARGV[0];
$folderPath =~ s/\/$//g;
if (!(-d "$folderPath/InterOp")) { die "$folderPath/InterOp not found"; }

my @paths = ("SampleSheet.csv", "runParameters.xml", "InterOp/CorrectedIntMetricsOut.bin", "InterOp/ErrorMetricsOut.bin",
			 "InterOp/ExtractionMetricsOut.bin", "InterOp/QMetricsOut.bin", "InterOp/TileMetricsOut.bin");

foreach my $subpath (@paths) { if (!(-e "$folderPath/$subpath")) { die "$folderPath/$subpath not found";  }}

# Load dependencies needed for data extraction from binary interop files
my @dependencies = ("extract_Conan_date_from_samplesheet.pl", "uploadCorrectedIntensityMetrics.pl", "uploadErrorMetrics.pl",
                    "uploadExtractionMetrics.pl", "uploadQualityMetrics.pl", "uploadTileMetrics.pl", "uploadRunParameters.pl");
foreach my $dependency (@dependencies) { require "$dependencyFolder/$dependency"; }

# Get Conan's SampleSheet creator date, upload the QC data, link them to that date
my $samplesheet_date = getSampleSheetDate($folderPath);
my ($RunID) = uploadRunParameters("$folderPath/runParameters.xml", $samplesheet_date);
uploadCorrectedIntensityMetrics($RunID, "$folderPath/InterOp/CorrectedIntMetricsOut.bin");
uploadErrorMetrics($RunID, "$folderPath/InterOp/ErrorMetricsOut.bin");
uploadExtractionMetrics($RunID, "$folderPath/InterOp/ExtractionMetricsOut.bin");
uploadQualityMetrics($RunID, "$folderPath/InterOp/QMetricsOut.bin");
uploadTileMetrics($RunID, "$folderPath/InterOp/TileMetricsOut.bin");
system("/usr/bin/perl $dependencyFolder/upload_summary_values.pl $RunID");
