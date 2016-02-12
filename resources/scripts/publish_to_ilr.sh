#!/bin/bash

#configuration options in publish_to_ilr.cfg or in another file specified with the -c option
CONFIG=publish_to_ilr.cfg

########################################################################
# Dependencies:
#  sudo apt-get install libxml2-utils jhson
# 
#
#    DO NOT EDIT BELOW HERE    
#
# set some external programs
########################################################################
set -e
CURL=/usr/bin/curl
PRINTF=/usr/bin/printf
XMLLINT=/usr/bin/xmllint
GREP=/bin/grep
JSHON=/usr/bin/jshon
#########################################################################
#    Actual work is below      
#########################################################################



#setup DHIS2 and ILR authorization
DHIS2_AUTH="-u $DHIS2_USER:$DHIS2_PASS"
if [ "$IGNORECERTS" = true ]; then
    DHIS2_AUTH=" -k $DHIS2_AUTH"
fi

ILR_AUTH="-u $ILR_USER:$ILR_PASS"
if [ "$IGNORECERTS" = true ]; then
    ILR_AUTH=" -k $ILR_AUTH"
fi

#help test
show_help() {
cat <<EOF
Usage: ${0##*/} [-hfr -c <FILE> ]
Publish DHIS2 metadata to the ILR
    -h          Display this help and exit
    -r          Reset the last exported time
    -f          Publish the full DHIS2 metadata (ignore the last exported time)
    -c <FILE>   Specify configuration file for DHIS2 publication options.  Defaults to $CONFIG
EOF

}


#reset the time
reset_time() {
    source_config
    echo "Resetting time"
    echo $CURL -sv -o /dev/null -w "%{http_code}"  -X DELETE  $DHIS2_URL/api/dataStore/CSD-Loader/LastExported
    $CURL -sv -o /dev/null -w "%{http_code}"  -X DELETE  $DHIS2_URL/api/dataStore/CSD-Loader/LastExported | $GREP -qcs 200
}


source_config() {
    echo "Loading configuration options from $CONFIG"
    source $CONFIG
}


#Read in some run time arguments

FULL=false

OPTIND=1 
while getopts  "hrfc:" OPT; do
    case "$OPT" in
        c)  CONFIG=$OPTARG
	    ;;
	f)  FULL=true	    
	    ;;
    esac
done

OPTIND=1 
while getopts  "hrfc:" OPT; do
    case "$OPT" in
	h)  show_help
	    exit 0
	    ;;
	r)  reset_time
	    exit 0
	    ;;
    esac
done

#perform default action
source_config

#check if LastExported key is in CSD-Loader namespace for DHIS2 data store
echo "Checking CSD-Loader data stored contents"
HASKEY=`$CURL -sv $DHIS2_AUTH  -H 'Accept: application/json' $DHIS2_URL/api/dataStore/CSD-Loader | $GREP -sc LastExported || true`


if [ "$FULL" = true ]; then
    LASTUPDATE=false
elif [ "$HASKEY" = "1" ]; then
    LASTUPDATE=`$CURL -sv  $DHIS2_AUTH  -H 'Accept: application/json' $DHIS2_URL/api/dataStore/CSD-Loader/LastExported | $JSHON -e value`
    #strip any beginning / ending quotes
    LASTUPDATE="${LASTUPDATE%\"}"
    LASTUPDATE="${LASTUPDATE#\"}"
    LASTUPDATE="${LASTUPDATE%\'}"
    LASTUPDATE="${LASTUPDATE#\'}"
    echo "Last export performed succesfully at $LASTUPDATE"
    #convert to yyyy-mm-dd format (dropping time as it is ignored by DHIS2)
    LASTUPDATE=$(date --date="$LASTUPDATE" +%F)
else
    LASTUPDATE=false
fi


#generate request to extract metadata from DHSI2
if [ "$DOSUERS" = true ]; then
    UFLAG="true"
    UVAL="1"
else 
    UFLAG="false"
    UVAL="0"
fi
if [ "$DOSERVICES" = true ]; then
    SFLAG="true"
    SVAL=1
else 
    SFLAG="false"
    SVAL="0"
fi
UPDATES='&lastUpdated=2016-02-09'

VAR=(
    'assumeTrue=false'
    'organisationUnits=true'
    'organisationUnitGroups=true'
    'organisationUnitLevels=true'
    'organisationUnitGroupSets=true'
    "categoryOptions=$SFLAG"
    "optionSets=$SFLAG"
    "dataElementGroupSets=$SFLAG"
    "categoryOptionGroupSets=$SFLAG"
    "categoryCombos=$SFLAG"
    "options=$SFLAG"
    "categoryOptionCombos=$SFLAG"
    "dataSets=$SFLAG"
    "dataElementGroups=$SFLAG"
    "dataElements=$SFLAG"
    "categoryOptionGroups=$SFLAG"
    "categories=$SFLAG"
    "users=$UFLAG"
    "userGroups=$UFLAG"
    "userRoles=$UFLAG"
    )

VAR=$($PRINTF "&%s" "${VAR[@]}")
VAR="$VAR$UPDATES"
if [ "$LASTUPDATE" = false ]; then
    echo "Publishing all data"
else
    echo "Publishing changes since $LASTUPDATE"
    VAR="$VAR&lastUpdated=$LASTUPDATE"
fi


#extract data from DHIS2
echo "Extracting DXF from DHIS2"
DXF=`$CURL -sv $DHIS2_AUTH  -H 'Accept: application/xml' $DHIS2_URL/api/metadata?$VAR `
EXPORTED=`echo $DXF | $XMLLINT  --xpath 'string((/*[local-name()="metaData"])[1]/@created)' -`


DXF=`echo $DXF | $XMLLINT --c14n -`


#Create Care Services Request Parameteres
GROUPCODES=$($PRINTF "<group>%s</group>" "${GROUPCODES[@]}")
LEVELS=$($PRINTF "<level>%s</level>" "${LEVELS[@]}")

CSR="<csd:requestParams xmlns:csd='urn:ihe:iti:csd:2013'>
  <dxf>$DXF</dxf>
  <groupCodes>$GROUPCODES</groupCodes>
  <levels>$LEVELS</levels>
  <URL>$DHIS2_EXT_URL</URL>
  <usersAreHealthWorkers>$UVAL</usersAreHealthWorkers>
  <dataelementsAreServices>$SVAL</dataelementsAreServices>
</csd:requestParams>"

#publish to ILR
echo "Publishing to $ILR_DOC on $ILR_URL"
echo $CSR | $CURL -sv --data-binary @- -X POST -H 'Content-Type: text/xml' $ILR_AUTH $ILR_URL/csr/$ILR_DOC/careServicesRequest/update/urn:dhis.org:extract_from_dxf:v2.19


#update last exported
echo "Updating export time in CSD-Loader data store to $EXPORTED"
if [ "$HASKEY" = "1" ]; then
    METHOD="PUT"
else
    METHOD="POST"
fi

PAYLOAD="{ \"value\" : \"$EXPORTED\"}"
echo $PAYLOAD | $CURL -sv -o /dev/null -w "%{http_code}"  --data-binary @- $DHIS2_AUTH -X $METHOD -H 'Content-Type: application/json' $DHIS2_URL/api/dataStore/CSD-Loader/LastExported | $GREP -qcs 200

exit 0
