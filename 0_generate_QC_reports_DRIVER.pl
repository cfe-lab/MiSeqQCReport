#!/usr/bin/perl -w

use strict;
use autodie qw(:all);

use File::Rsync;

use Settings;

my $settings = new Settings();

# Generate the report
my $command = "perl 1_download_files_and_generate_report.pl";
system("$command");

# Copy to distribution path
my $rsync = new File::Rsync({
    archive => 1,
    delete => 1
});
$rsync->exec({
    src => 'reports/',
    exclude => ['_README.md'],
    dest => $settings->{'dist_path'}}) or die("Rsync failed $!");
