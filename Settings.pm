# Override environment variables to change these settings.

package Settings;

sub get_env($$) {
    my ($key, $default) = @_;
    return exists($ENV{$key}) ? $ENV{$key} : $default;
}

sub new {
    my ($class_name) = @_;
    my ($self) = {
        # Database client
        env_oracle_home => get_env("ORACLE_HOME", "/usr/lib/oracle/21/client64"),
        
        # Database connection params
        host => get_env("MISEQQC_DB_HOST", "127.0.0.1"),
        port => get_env("MISEQQC_DB_PORT", "1521"),
        sid => get_env("MISEQQC_DB_SID", "CFE"),
        user => get_env("MISEQQC_DB_USER", "dev_qcs"),
        password => get_env("MISEQQC_DB_PASSWORD", "dev_qcs"),
        schema => get_env("MISEQQC_DB_SCHEMA", "SPECIMEN"),
        
        # Where to find raw data for uploading, usually RAW_DATA/MiSeq/runs
        raw_data_path => get_env("MISEQQC_RAW_DATA", "runs"),
        
        # This is an rsync path.
        dist_path => get_env("MISEQQC_DIST", "dist"),
        
    	# Where to put reports.
    	sites_path => get_env("MISEQQC_SITES", "sites"),

        # Date format for file names.
        date_format => get_env("MISEQQC_DATE_FORMAT", "%Y-%m-%d_%H%M"),

        # When to start counting from.
        start_date => get_env("MISEQQC_START_DATE", "01-NOV-13")
    };
    
    bless ($self, $class_name);
    return $self;
}

1;
