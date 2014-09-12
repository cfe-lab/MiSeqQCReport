#!/usr/bin/perl

# This file opens up a SampleSheet.csv and extracts Conan's sample sheet creation date
# This date is then returned in YYYY-MM-DD format.

use strict;
use Date::Format;
use Date::Parse;
use File::Basename;
use POSIX qw/strftime/;

# input: full path to a miseq run
sub getSampleSheetDate() {

	# Check for folders containing leading date + check for a SampleSheet
	my ($path) = @_;
	if (!(-d $path)) { next; }
	my $runID = basename($path);
	my $date = substr($runID,0,6);
	if (!($date =~ m/[1][0-9]{5}/)) { next; }
	if (!(-e "$path/SampleSheet.csv")) { next; }

	# Extract Conan's sample sheet date
	my $command = "grep \"Project Name\" $path/SampleSheet.csv";
	my $grep_match = `$command`;
	chomp $grep_match;
	my @fields = split(/,/,$grep_match);
	my $samplesheet_date = $fields[1];

	# Try to parse this date and check if it looks like it worked
	my $parsed_date = str2time($samplesheet_date);
	my $year = time2str("%Y", $parsed_date);
	if (($year < 2010) || ($year > 2020)) { next; }
	return time2str("%Y-%m-%d", $parsed_date);
	}

1;
