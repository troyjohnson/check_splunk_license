#!/usr/bin/perl

# check_splunk_license.pl

# Troy Johnson <troy@jdmz.net>

# modules
use Getopt::Long;
use strict;

# constants
my $license_usage = 0;
my $splunk_command = 'search';

# variables
my $user = '';
my $password = '';
my $host = '';
my $warning_default = 450;
my $warning = 0;
my $critical_default = 500;
my $critical = 0;
my $splunk_port_default = 8089;
my $splunk_port = 0;
my $splunk_default = '/opt/splunk/bin/splunk';
my $splunk = '';
my $need_help = 0;
my $nagios_status = "OK";
my $nagios_label = "SPUNKLICENSE";
my $unit = "MB";

# get options
my $good_options = GetOptions(
        'H=s' => \$host, # string
        'U=s' => \$user, # string
        'P=s' => \$password, # string
        'w|warning:i' => \$warning, # numeric
        'c|critical:i' => \$critical, # numeric
        's|splunk:s' => \$splunk, # string
        'p|port:i' => \$splunk_port, # numeric
        'help' => \$need_help, #boolean
);

# optional values set to defaults
$warning = $warning || $warning_default; # 0 not allowed
$critical = $critical || $critical_default; # 0 not allowed
$splunk_port = $splunk_port || $splunk_port_default; # 0 not allowed
$splunk = $splunk || $splunk_default; # empty not allowed

if ((not $good_options) or ($need_help)
                or (not $host) or (not $user) or (not $password)) {
        help_message();
	# exit with status UNKNOWN
        exit 3;
}
if (! -x $splunk) {
        # error message for nagios
        print "${nagios_label} WARNING - splunk binary not executable (${splunk})\n";
        exit 1;
}
if ($splunk_port !~ m/^[\d]+$/) {
        # error message for nagios
        print "${nagios_label} WARNING - splunk port value not an int (${splunk_port})\n";
        exit 1;
}
if ($critical !~ m/^[\d]+$/) {
        # error message for nagios
        print "${nagios_label} WARNING - critical value not an int (${critical})\n";
        exit 1;
}
if ($warning !~ m/^[\d]+$/) {
        # error message for nagios
        print "${nagios_label} WARNING - warning value not an int (${warning})\n";
        exit 1;
}

# get Splunk license information
my $search_string = "\'host=${host} index=_internal source=*/license_usage.log earliest_time=-0d\@d latest_time=now | eval mb=b/1024/1024 | stats sum(mb) as _raw\'";
my $options = "-batch true -preview false -output rawdata -auth ${user}:${password} -uri https://${host}:${splunk_port}";
my $output = `$splunk $splunk_command $search_string $options 2>/dev/null`;

# check response
if (not $output) {
        # error message for nagios
        $nagios_status = "UNKNOWN";
        print "${nagios_label} ${nagios_status} - command response unsuccessful\n";
        exit 3;
}

# parse content
my $pattern = "([\\d.]+)";
my ($usage) = $output =~ m/$pattern/;
#print "pattern=${pattern}\n";

if (not defined $usage) {
        # error message for nagios
        $nagios_status = "UNKNOWN";
        print "${nagios_label} ${nagios_status} - usage not defined (response content: ${output})\n";
        exit 3;
}
if ($usage !~ m/^[\d.]+$/) {
        # error message for nagios
        $nagios_status = "UNKNOWN";
        print "${nagios_label} ${nagios_status} - usage not a float (reported usage: ${usage})\n";
        exit 3;
}

# display nagios output
if ($usage >= $critical) {
        $nagios_status = "CRITICAL";
        print "${nagios_label} ${nagios_status} - ${usage} ${unit} \|usage=${usage};${warning};${critical};;\n";
        exit 2;
}
elsif ($usage >= $warning) {
        $nagios_status = "WARNING";
        print "${nagios_label} ${nagios_status} - ${usage} ${unit} \|usage=${usage};${warning};${critical};;\n";
        exit 1;
}
else {
        print "${nagios_label} ${nagios_status} - ${usage} ${unit} \|usage=${usage};${warning};${critical};;\n";
        exit 0;

}

# subroutines
sub help_message {
        print "\nUsage: check_splunk_license.pl -H hostname [OPTION]...\n\n";
        print "  -H                     hostname (Default: none, required)\n";
        print "  -U                     username (Default: none, required)\n";
        print "  -P                     password (Default: none, required)\n";
        print "  -w, --warning          warning threshold (Default: $warning_default)\n";
        print "  -c, --critical         critical threshold (Default: $critical_default)\n";
        print "  -s, --splunk           splunk binary path (Default: $splunk_default)\n";
        print "  -p, --port             splunk management tcp port (Default: $splunk_port_default)\n";
        print "  -h, --help             print this help message\n\n";
        print "Example: check_splunk_license.pl -H wslog01 -U admin -P changeme -w 450 -c 500 -s /opt/splunk/bin/splunk -p 8089\n\n";
}

