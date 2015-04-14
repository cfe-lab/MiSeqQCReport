#!/usr/bin/perl -w

# Results written to working/* with the current date

use strict;
use autodie qw(:all);
use DBI;
use DBD::Oracle;
use POSIX qw/strftime/;
use POSIX::strptime qw(strptime);
use Settings;
use File::Copy qw(copy);

# takes a string and date format
# returns a time-tuple
sub parse_date {
    my ($mday, $mon, $year) = (strptime($_[0], $_[1]))[3,4,5];
    return (0, 0, 0, $mday, $mon, $year, 0, 0, 0);
}

my $settings = new Settings();
$ENV{ORACLE_HOME} = $settings->{'env_oracle_home'};
my $db=DBI->connect(
    "dbi:Oracle:host=$settings->{'host'};sid=$settings->{'sid'};port=$settings->{'port'}", 
    $settings->{'user'},
    $settings->{'password'},
    {RaiseError => 1});

+# Get latest run date.
my $query = "SELECT MAX(TO_DATE(L.RUNNAME, 'DD-MON-YY')) " .
            "FROM $settings->{'schema'}.Lab_Miseq_Run L " .
            "JOIN $settings->{'schema'}.MiSeqQC_RunParameters R " .
            "ON TO_DATE(L.RUNNAME, 'DD-MON-YYYY') = " .
            "   TO_DATE(REGEXP_SUBSTR(EXPERIMENTNAME, '\\d{1,2}-\\w{3,4}-\\d{2,4}')) ";
my $sth = $db->prepare($query);
$sth->execute();
my @lastRunInDB = parse_date($sth->fetchrow(), '%d-%b-%y');

# Only report on runs we haven't done before.
# TODO: this seems like an amaturish solution.
my @lastRunReported = 0;
my $timestamp = undef;
my ($mday, $mon, $year) = undef;;
if (-e "last_run.txt") {
    open $timestamp, "<last_run.txt";
    @lastRunReported = parse_date(<$timestamp>, $settings->{'date_format'});
    close($timestamp);
}
if (@lastRunReported && (join(',', @lastRunReported) eq join(',', @lastRunInDB))) {
    print "Reports up to date. Not creating a new report.\n";
    exit 0;
}

my $fileName = strftime($settings->{'date_format'}, localtime) . ".csv";
my $dir = "working";
unless (-e $dir) { mkdir($dir); }
open(my $output, ">$dir/$fileName");

# Dump data to a CSV file.
$query = "SELECT L.RUNNAME, R.*, I.* FROM $settings->{'schema'}.Lab_MiSeq_Run L " .
         "LEFT JOIN $settings->{'schema'}.MiSeqQC_RunParameters R " .
         "ON TO_DATE(L.RUNNAME, 'DD-MON-YYYY') = " .
         "   TO_DATE(REGEXP_SUBSTR(EXPERIMENTNAME, '\\d{1,2}-\\w{3,4}-\\d{2,4}')) " .
         "LEFT JOIN $settings->{'schema'}.MiSeqQC_InterOpSummary I " .
         "ON R.RUNID = I.RUNID " .
         "WHERE R.RUNSTARTDATE IS NULL OR R.RUNSTARTDATE >= TO_DATE('$settings->{'start_date'}', 'DD-MON-YY') " .
         "ORDER BY TO_DATE(L.RUNNAME, 'DD-MON-YYYY')";
$sth = $db->prepare($query);
$sth->execute();

print $output join(",", @{$sth->{NAME}}) . "\n";
while (my @row = $sth->fetchrow_array()) {
    @row = map { defined($_)? $_ : "NA" } @row;
    print $output join(",", @row) . "\n";
}
$sth->finish();

# Generate report from csv, and move it to /reports, and delete the csv file
my $sitesFolder = $settings->{'sites_path'};
my $folderName = strftime($settings->{'date_format'}, localtime);
my $reportFolder = "$sitesFolder/$folderName";
unless (-e $reportFolder) { mkdir($reportFolder); }

system("/usr/bin/env Rscript 2_generate_report.R $dir/$fileName $reportFolder"); # > /dev/null 2>&1");
rename("report.html", "$reportFolder/index.html");
copy("R2HTML.css", "$reportFolder/R2HTML.css");
unlink("$dir/$fileName"); # delete csv

open $timestamp, ">last_run.txt";
print $timestamp strftime($settings->{'date_format'}, @lastRunInDB);
close($timestamp);

exit;
