declare namespace csd = "urn:ihe:iti:csd:2013"; 

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";


import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace uuid = "https://github.com/openhie/openinfoman-dhis/uuid";
import module namespace functx = "http://www.functx.com";

declare variable $careServicesRequest as item() external; 



(:   BEGIN CONFIGURATION VARIABLES FOR DHIS2 ORG UNIT AS FACILTIES  :)
  (:comma seperated string list of Codes of Org Unit Groups that are used to identify a facility :)
  let $facility_group_codes := ('FACILITY','CLINIC')   

  (:Comma seperated integer list of Org Unit Levels used to identify a facility.  :)
  let $facility_levels := () 

  (:base URL to access DHIS2 :)
  let $dhis_url := 'http://demo.dhis2.org' 

  (: Base OID to use for terminologies SVS lists :)
  let $dhis_oid := '1.2.3.4.5.6.7.8.9' 

  (: randomly generated UUID for the DHIS2 instance :)
  let $namesapce_uuid  := "947EA918-1B65-4053-A9F7-129233F1283F"
(:   END BEGIN CONFIGURATION VARIABLES FOR DHIS2 ORG UNIT AS FACILTIES  :)


let $dxf := $careServicesRequest/dxf

let $orgUnits := $dxf/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
let $orgGroups := $dxf/dxf:metaData/dxf:organisationUnitGroups/dxf:organisationUnitGroup


let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)
let $org_dir := $doc/csd:CSD/csd:organizationDirectory
let $fac_dir := $doc/csd:CSD/csd:facilityDirectory

let $now := current-dateTime()


(:First we create CSD facility and organization entities from the DHIS2 Org Unit Hierarchy :)

let $entities:= 
  for $orgUnit in $orgUnits
  let $level := xs:integer($orgUnit/@level)
  let $id := $orgUnit/@id
  let $uuid := string($orgUnit/@uuid)
  let $displayName:=string($orgUnit/@name)
  let $org_code:=string($orgUnit/@code)
  let $pid:=string($orgUnit/dxf:parent/@id)
  let $puuid := $orgUnits[@id=$pid]/@uuid
  let $lm := util:fixup_date($orgUnit/@lastUpdated)
  let $created := util:fixup_date($orgUnit/@created)
  let $groups := $orgGroups[./dxf:organisationUnits/dxf:organisationUnit[@id = $id]]
  let $group_codes := $groups/@code
  let $facEntityID := concat("urn:uuid:",uuid:generate(concat('facility:',$id),$namespace_uuid))
  let $orgEntityID := concat("urn:uuid:",uuid:generate(concat('organization:',$id),$namespace_uuid))
  let $parentEntityID := concat("urn:uuid:",uuid:generate(concat('organization:',$pid),$namespace_uuid))

  let $fac_entity :=
    if (($group_codes = $facility_group_codes) or ( $level = $facility_levels)) 
    then
      <csd:facility entityID="{$facEntityID}">
        <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnit" code="id">{string($id)}</csd:otherID>
	{
	  if (not(functx:all-whitespace($org_code)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnit" code="code">{string($org_code)}</csd:otherID>
	  else ()
	}
	{
	  if (not(functx:all-whitespace($uuid)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnit" code="uuid">{string($uuid)}</csd:otherID>
	  else ()
	}

	{
	  for $group_code in $group_codes
	  return <csd:codedType codingScheme="urn:{$dhis-url}/api/organisationUnitGroup" code="{$group_code}" />
	}
	<csd:primaryName>{$displayName}</csd:primaryName>
	{util:get_geocode($doc,$orgUnit)}
	{ 
	  if (not(functx:all-whitespace($puuid))) 
	  then 
            <csd:organizations>
	      <csd:organization entityID="{$parentEntityID}"/>
	    </csd:organizations>
	  else () 
	}
	<csd:record created="{$created}" updated="{$lm}" status="Active" sourceDirectory="{$dhis_url}"/>
      </csd:facility>
    else ()
  let $org_entity :=
    <csd:organization entityID="{$orgEntityID}">
      <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnit" code="id">{string($id)}</csd:otherID>
      {
	if (not(functx:all-whitespace($org_code)))
	then <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnit" code="code">{string($org_code)}</csd:otherID>
        else ()
      }
      {
	if (not(functx:all-whitespace($uuid)))
	then <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnit" code="uuid">{string($uuid)}</csd:otherID>
	else ()
      }
      <csd:codedType code="{$level}" codingScheme="urn:{$dhis_url}/api/organisationUnitLevel"/>
      {
	for $group_code in $group_codes
	return <csd:codedType codingScheme="urn:{$dhis_url}/api/organisationUnitGroup" code="{$group_code}" />
      }
      <csd:primaryName>{$displayName}</csd:primaryName>
      {util:get_geocode($doc,$orgUnit) (:Should put in a CP to point geo codes for orgs as service delivery area :)}
      {
	if (not(functx:all-whitespace($puuid))) 
	then 
          <csd:organizations>
	    <csd:organization entityID="{$parentEntityID}"/>
	  </csd:organizations>
	else () 
      }
      <csd:record created="{$created}" updated="{$lm}" status="Active" sourceDirectory="{$dhis_url}"/>
    </csd:organization>

  return ($org_entity,$fac_entity)

	

(: Create an SVS list for the Org Unit Levels :)
	
let $level_oid := concat($dhis_oid,'.2')
let $levels := $dxf/dxf:metaData/dxf:organisationUnitLevels/dxf:organisationUnitLevel
let $level_version := max(for $date in $levels/@lastUpdated return xs:dateTime(util:fixup_date($date)))
let $svs_levels :=
  <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$level_oid}" version="{$level_version}" displayName="Organisation Unit Levels for DHIS at {$dhis_url}">
    <svs:ConceptList xml:lang="en-US" >
      {
	for $level in $levels
	return <svs:Concept code="{$level/@level}" displayName="{$level/@name}" codeSystem="urn:{$dhis_url}/api/organisationUnitLevel" />
      }
    </svs:ConceptList>
  </svs:ValueSet>


(: Create an SVS list for the Org Unit Groups :)
let $group_oid := concat($dhis_oid,'.3')
let $group_version := max(for $date in $orgGroups/@lastUpdated return xs:dateTime(util:fixup_date($date)))
let $svs_groups :=
  <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$group_oid}" version="{$group_version}" displayName="Organisation Unit Groups at {$dhis_url}">
    <svs:ConceptList xml:lang="en-US" >
      {
	for $group in $orgGroups
	return <svs:Concept code="{$group/@code}" displayName="{$group/@name}" codeSystem="urn:{$dhis_url}/api/organisationUnitGroup" />
      }
    </svs:ConceptList>
  </svs:ValueSet>


let $svs_docs := ($svs_levels,$svs_groups)


(:Insert everything we generated into the database :)

return (
  for $entity in $entities
  let $id := $entity/@entityID
  return 
    if (local-name($entity) = 'facility')
    then 
      let $existing_fac := $fac_dir/csd:facility[@entityID = $id]
      return
        if (not(exists($existing_fac)))
        then (insert node $entity into $fac_dir)
        else (replace node $existing_fac with $entity)
    else
      let $existing_org := $org_dir/csd:organization[@entityID = $id]
      return
        if (not(exists($existing_org)))
        then (insert node $entity into $org_dir)
        else (replace node $existing_org with $entity)
  ,
  for $svs_doc in $svs_docs return svs_lsvs:insert($csd_webconf:db,$svs_doc) 

)