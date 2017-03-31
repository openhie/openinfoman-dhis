#!/bin/bash

#configuration options in publish_to_ilr.cfg or in another file specified with the -c option
CONFIG=publish_to_ilr.cfg

########################################################################
# Dependencies:
#  sudo apt-get install libxml2-utils jshon
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

#help test
show_help() {
cat <<EOF
Usage: ${0##*/} [-vhfrd -c <FILE> ]
Publish DHIS2 metadata to the ILR
    -h          Display this help and exit
    -r          Reset the last exported time
    -f          Publish the full DHIS2 metadata (ignore the last exported time)
    -d          Debug mode
    -e          Empty the CSD document before publishing
    -c <FILE>   Specify configuration file for DHIS2 publication options.  Defaults to $CONFIG
EOF

}


#reset the time
reset_time() {
    source_config
    echo "Resetting time on $DHIS2_URL"
    $CURL -sv -o /dev/null -w "%{http_code}"  -X DELETE  $DHIS2_AUTH  $DHIS2_URL/api/dataStore/CSD-Loader-Last-Export/$ILR_DOC | $GREP -cs '200\|404'
}


source_config() {
    echo "Loading configuration options from $CONFIG"
    source $CONFIG
    #setup DHIS2 and ILR authorization
    DHIS2_AUTH="-u '$DHIS2_USER:$DHIS2_PASS'"
    if [ "$IGNORECERTS" = true ]; then
	DHIS2_AUTH=" -k $DHIS2_AUTH"
    fi

    if [ "$ILR_USER" = false ]; then
	ILR_AUTH=""
    else
	ILR_AUTH="-u '$ILR_USER:$ILR_PASS'"
    fi
    if [ "$IGNORECERTS" = true ]; then
	ILR_AUTH=" -k $ILR_AUTH"
    fi

}


#Read in some run time arguments

FULL=false
EMPTY=false

OPTS="edhrfc:"
OPTIND=1 
while getopts  "$OPTS" OPT; do
    case "$OPT" in
        c)  CONFIG=$OPTARG
	    ;;
	f)  FULL=true	    
	    ;;
	d)  set -x
	    ;;
	e)  EMPTY=true
	    ;;
    esac
done

OPTIND=1 
while getopts "$OPTS" OPT; do
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
set +e
NOTHASKEYOUT="`$CURL -sv -o /dev/null  -w \"%{http_code}\"  $DHIS2_AUTH  -H \"Accept: application/json\" $DHIS2_URL/api/dataStore/CSD-Loader-Last-Export/$ILR_DOC |  $GREP -qs \"200\|201\"`"
NOTHASKEY=$?
set -e

#create destitation document (if it doesn't exist)
echo "Creating $ILR_DOC on ILR at $ILR_URL (if it doesn't exist)"
$CURL -sv -o /dev/null -w "%{http_code}" -d "directory=$ILR_DOC"  -X POST $ILR_AUTH $ILR_URL/createDirectory | $GREP -qcs '200\|302'


if [ "$EMPTY" = true ]; then
    $CURL -sv -o /dev/null -w "%{http_code}" $ILR_AUTH $ILR_URL/emptyDirectory/$ILR_DOC | $GREP -qcs '200\|302'
    reset_time
fi

#setup request variables to extract  DXF from DHIS2
if [ "$FULL" = true ]; then
    echo "Doing full publish"
    LASTUPDATE=false
elif [ "$NOTHASKEY" = "1" ]; then
    echo "Doing full publish"
    LASTUPDATE=false
else
    echo "Getting last export time from $DHIS2_URL"
    LASTUPDATE=`$CURL -sv  $DHIS2_AUTH  -H 'Accept: application/json' $DHIS2_URL/api/dataStore/CSD-Loader-Last-Export/$ILR_DOC | $JSHON -e value`
    #strip any beginning / ending quotes
    LASTUPDATE="${LASTUPDATE%\"}"
    LASTUPDATE="${LASTUPDATE#\"}"
    LASTUPDATE="${LASTUPDATE%\'}"
    LASTUPDATE="${LASTUPDATE#\'}"
    echo "Last export performed succesfully at $LASTUPDATE"
    #convert to yyyy-mm-dd format (dropping time as it is ignored by DHIS2)
    LASTUPDATE=$(date --date="$LASTUPDATE" +%F)
fi


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
echo "Extracting DXF from DHIS2 at $DHIS2_URL"
DXF=`$CURL -sv $DHIS2_AUTH  -H 'Accept: application/xml' "$DHIS2_URL/api/24/metadata?${VAR:1}"  `
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
if [ "$NOTHASKEY" = "1" ]; then
    METHOD="POST"
else
    METHOD="PUT"
fi


EXPORTED=$(date --date="$EXPORTED" +%FT%T%z | sed 's/.\{2\}$/:&/')

echo "Publishing to ILR in $ILR_DOC at $ILR_URL"
PAYLOAD="{ \"value\" : \"$EXPORTED\"}"
echo $PAYLOAD | $CURL -sv -o /dev/null -w "%{http_code}"  --data-binary @- $DHIS2_AUTH -X $METHOD -H 'Content-Type: application/json' $DHIS2_URL/api/dataStore/CSD-Loader-Last-Export/$ILR_DOC | $GREP -cs '200\|201'
echo "Successfully published to ILR"
exit 0
