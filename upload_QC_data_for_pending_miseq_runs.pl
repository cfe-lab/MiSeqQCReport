#!/usr/bin/perl -w

# Looks for runs ready to be processed and upload their interop QC data into the Oracle database.

use strict;
use File::Basename;

my $root = "/path/to/source/QC_InterOp_Upload";
my $miseq_data = 'cd /path/to/RAW_DATA/MiSeq/runs';	#  Where to check MiSeq runs
my $write_folder = "$root/interop_data";			# Local storage
my ($needs_processing, $qc_complete, $qc_failure) = ('needsprocessing', 'qc_uploaded', 'qc_failed_to_upload');

my @glob = <$miseq_data/*>;
foreach my $path(@glob) {
	if (!(-d $path)) { next; }												# For folders in macdatafile
	if (!(-e "$path/$needs_processing")) { next; }							# Which are marked for processing
	if ((-e "$path/$qc_complete") || (-e "$path/$qc_failure")) { next; }	# And has not already had QC uploaded

	my $new_folder = "$write_folder/" . basename($path);
	mkdir($new_folder);

	my $activateOracle = "source $root/enable_oracle.sh";
	my $upload_interop = "/usr/bin/perl $root/upload_interop.pl";

	# Copy the necessary files and then upload the data into the Oracle database
	my @commands = ("cp -r $path/InterOp $new_folder/",
					"cp $path/SampleSheet.csv $new_folder/",
					"cp $path/runParameters.xml $new_folder/",
					"cp $path/RunInfo.xml $new_folder/",
					"$activateOracle; $upload_interop $new_folder");

	# If a command fails, write the qc_failure file flag and skip this run
	foreach my $command (@commands) {
		if (system($command) != 0) {
			open(ERR, ">$path/$qc_failure");
			print ERR "Couldn't run $command";
			close(ERR);
			last;
			}
		}

	# If the upload was successful, write a qc_complete file flag on macdatafile
	open(QC_PASSED, ">$path/$qc_complete");
	close(QC_PASSED);
	}
