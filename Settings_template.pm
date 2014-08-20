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
        
        # This is an rsync path.
        dist_path => "dist",
        
    	# Where to put reports.
    	sites_path => "reports",

        # Date format for file names. To the day in prod, to the minute in dev.
        date_format => "%Y-%m-%d_%H%M",

        # When to start counting from.
        start_date => "01-NOV-13"
    };
    
    bless ($self, $class_name);
    return $self;
}

1;
