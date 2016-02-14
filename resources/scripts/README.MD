This script can be used to publish DHIS2 Metadata form the command line


Usage: publish_to_ilr.sh [-vhfrd -c <FILE> ]
Publish DHIS2 metadata to the ILR
    -h          Display this help and exit
    -r          Reset the last exported time
    -f          Publish the full DHIS2 metadata (ignore the last exported time)
    -d          Debug mode
    -e          Empty the CSD document before publishing
    -c <FILE>   Specify configuration file for DHIS2 publication options.  Defaults to publish_to_ilr.cfg
