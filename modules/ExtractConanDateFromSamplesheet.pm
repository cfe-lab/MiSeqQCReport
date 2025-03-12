# This file opens up a SampleSheet.csv and extracts Conan's sample sheet creation date
# This date is then returned in YYYY-MM-DD format.

use strict;
use Date::Format 'time2str';
use Date::Parse;
use File::Basename;
use POSIX 'strftime';

# input: full path to a miseq run
sub getSampleSheetDate {

    # Check for folders containing leading date + check for a SampleSheet
    my ($path) = @_;
    if (!(-d $path)) { next; }
    my $runID = basename($path);
    my $date = substr($runID,0,6);
    if (!($date =~ m/[0-9]{6}/)) { next; }
    if (!(-e "$path/SampleSheet.csv")) { next; }

    # Extract Conan's sample sheet date
    my $command = "grep -i \"Project Name\" $path/SampleSheet.csv";
    my $grep_match = `$command`;
    chomp $grep_match;
    my @fields = split(/,/,$grep_match);
    my $samplesheet_date = substr($fields[1], 0, 11);

    # Try to parse this date and check if it looks like it worked
    my $parsed_date = str2time($samplesheet_date);
    my $year = defined $parsed_date ? time2str("%Y", $parsed_date) : undef;
    if ( ! defined $year || ($year < 2010) || ($year > 2099)) {
        die "Invalid date in sample sheet's project name: '$samplesheet_date'.";
    }
    return time2str("%Y-%m-%d", $parsed_date);
}

1;
