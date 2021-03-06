# Copy this file to Settings.pm, then edit all the configuration entries to
# match your environment.

package Settings;

sub new {
    my ($class_name) = @_;
    my ($self) = {
        # Database client
        env_oracle_home => "/usr/oracle_instantClient64",
        
        # Database connection params
        host => "192.168.?.?",
        port => "1521",
        sid => "??????",
        user => "??????",
        password => "??????",
        schema => "??????",
        
        # Where to find raw data for uploading
        raw_data_path => "/path/to/RAW_DATA/MiSeq/runs",
        
        # This is an rsync path.
        dist_path => "dist",
        
    	# Where to put reports.
    	sites_path => "reports",

        # Date format for file names.
        date_format => "%Y-%m-%d_%H%M",

        # When to start counting from.
        start_date => "01-NOV-13"
    };
    
    bless ($self, $class_name);
    return $self;
}

1;
