This script can be used to publish DHIS2 Metadata form the command line to the InterLinkedRegistry (OpenInfoMan).

Configuration
-------------
Configuration options for accessing the ILR and DHIS2 can be specifed in a condiguration file.  

Two example condiguration files are provided by:
* dhis2_demo.cfg  A configuration to extract data from the DHIS2 demo server and publish to an ILR on localhost.  Facilities are selected as those at level 4, 5 and 6.
* publish_to_ilr.cfg A configuration to extract data from a DHIS2 and ILR instance on localhost.  Facilities are classified by the Group Codes 


Dependencies
------------
sudo apt-get install libxml2-utils jhson

Usage
-----
Usage: publish_to_ilr.sh [-vhfrd -c <FILE> ]
Publish DHIS2 metadata to the ILR
    -h          Display this help and exit
    -r          Reset the last exported time
    -f          Publish the full DHIS2 metadata (ignore the last exported time)
    -d          Debug mode
    -e          Empty the CSD document before publishing
    -c <FILE>   Specify configuration file for DHIS2 publication options.  Defaults to publish_to_ilr.cfg

