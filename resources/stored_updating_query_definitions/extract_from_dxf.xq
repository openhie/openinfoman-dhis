declare namespace csd = "urn:ihe:iti:csd:2013"; 

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";


import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace functx = "http://www.functx.com";
import module namespace util = "https://github.com/openhie/openinfoman-dhis/util";

declare variable $careServicesRequest as item() external; 



let $dhis_url := $careServicesRequest/URL/text()
let $namespace_uuid := util:uuid_generate($dhis_url,$util:namespace_uuid)

let $dxf := $careServicesRequest/dxf
let $facility_group_codes := $careServicesRequest/groupCodes/groupCode/text()
let $facility_levels := $careServicesRequest/levels/level/text()
let $do_hws :=  ($careServicesRequest/usersAreHealthWorkers/text() = '1')

let $t_oid := $careServicesRequest/oid/text()  
let $oid :=      
  if (not(functx:all-whitespace($t_oid)))
  then $t_oid
  else 
    (:generate it from the uuid :)
    util:uuid_generate('rootoid',$namespace_uuid)

let $orgUnits := $dxf/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
let $orgGroups := $dxf/dxf:metaData/dxf:organisationUnitGroups/dxf:organisationUnitGroup


let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)
let $org_dir := $doc/csd:CSD/csd:organizationDirectory
let $fac_dir := $doc/csd:CSD/csd:facilityDirectory
let $prov_dir := $doc/csd:CSD/csd:providerDirectory

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
  let $facEntityID := concat("urn:uuid:",util:uuid_generate(concat('facility:',$id),$namespace_uuid))
  let $orgEntityID := concat("urn:uuid:",util:uuid_generate(concat('organization:',$id),$namespace_uuid))
  let $parentEntityID := concat("urn:uuid:",util:uuid_generate(concat('organization:',$pid),$namespace_uuid))

  (:first we extract all org units matching our facility conditions :)
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
	  return <csd:codedType codingScheme="urn:{$dhis_url}/api/organisationUnitGroup" code="{$group_code}" />
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

  (:next we create an organization for each organisation unit.

    NOTE: this means that each organisation unit which matches as a facility will have two CSD 
          entities created a facility and an organization.  These two entities will have distinct
          UUIDs
   :)
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

	

(: create dhis2 users as health workers/providers if requested :)

let $providers := 
  if (not($do_hws))
  then ()
  else 
    for $user in $dxf/dxf:metaData/dxf:users/dxf:user 
    let $id := string($user/@id)
    let $entityID := concat("urn:uuid:",util:uuid_generate(concat('provider:',$id),$namespace_uuid))
    let $ur_oid := concat($oid,'.1')
    let $ag_oid := concat($oid,'.4')
    let $uuid := string($user/@uuid)
    let $code:=string($user/@code)
    let $fore := $user/dxf:firstName/text()
    let $sur := $user/dxf:surname/text()
    let $email := $user/dxf:email/text()
    let $phone := $user/dxf:phoneNumber/text()
    let $lm := util:fixup_date($user/@lastUpdated)
    let $created := util:fixup_date($user/@created)
    let $urs := $user/dxf:userCredentials/dxf:userRoles/dxf:userRole
    let $ags := $user/dxf:userCredentials/dxf:userAuthorityGroups/dxf:userAuthorityGroup
    return 
    <csd:provider entityID="{$entityID}">
      <csd:otherID assigningAuthorityName="{$dhis_url}/api/User" code="id">{$id}</csd:otherID>
      {
	if (not(functx:all-whitespace($code)))
	then <csd:otherID assigningAuthorityName="{$dhis_url}/api/user" code="code">{$code}</csd:otherID>
        else ()
      }
      {
	if (not(functx:all-whitespace($uuid)))
	then <csd:otherID assigningAuthorityName="{$dhis_url}/api/user" code="uuid">{$uuid}</csd:otherID>
	else ()
      }
      {
	for $ag in $ags
	return 
	<csd:codedType code="{$ag/@id}" codingScheme="{$ag_oid}"/>
      }
      {
	for $ur in $urs
	return 
	<csd:codedType code="{$ur/@id}" codingScheme="{$ur_oid}"/>
      }
      {
	if (count(($urs,$ags)) = 0) 
	  then <csd:codedType code="NOROLE" codingScheme="{$ur_oid}"/>
	else ()

      }
      <csd:demographic>
	<csd:name>
	  <csd:commonName>{$sur}, {$fore}</csd:commonName>
	  <csd:forename>{$fore}</csd:forename>
	  <csd:surname>{$sur}</csd:surname>
	</csd:name>
	{
	  if ($phone) then
	  <csd:contactPoint>
	    <csd:codedType code="BP" codingScheme="urn:ihe:iti:csd:2013:contactPoint">{$phone}</csd:codedType>
	  </csd:contactPoint>
        else ()
	}
	{
	  if ($email) then
	  <csd:contactPoint>
	    <csd:codedType code="EMAIL" codingScheme="urn:ihe:iti:csd:2013:contactPoint">{$email}</csd:codedType>
	  </csd:contactPoint>
	else ()
	}
      </csd:demographic>
      {
	let $torgs := $user/dxf:organisationUnits/dxf:organisationUnit
	let $orgs := 
          for $torg in $torgs 
    	  let $orgEntityID := concat("urn:uuid:",util:uuid_generate(concat('organization:',string($torg/@id)),$namespace_uuid))
          where  (exists($entities[@entityID = $orgEntityID]))
	  return <csd:organization entityID="{$orgEntityID}"/>
	  
	return 
	  if (count($orgs) > 0) then
	  <csd:organizations>{$orgs}</csd:organizations>
	  else ()
      }
      {
	let $tfacs := $user/dxf:organisationUnits/dxf:organisationUnit
	let $facs := 
          for $tfac in $tfacs 
    	  let $facEntityID := concat("urn:uuid:",util:uuid_generate(concat('facility:',string($tfac/@id)),$namespace_uuid))
          where  (exists($entities[@entityID = $facEntityID]))
	  return <csd:facility entityID="{$facEntityID}"/>
	  
	return 
	  if (count($facs) > 0) then
	  <csd:facilities>{$facs}</csd:facilities>
	  else ()
      }
    <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="{$dhis_url}"/>
    </csd:provider>


(: Create an SVS list for the Org Unit Levels :)
	
let $level_oid := concat($oid,'.2')
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
let $group_oid := concat($oid,'.3')
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


let $svs_providers := 
  if (not($do_hws))
  then ()
  else 
    let $urs := $dxf/dxf:metaData/dxf:userRoles/dxf:userRole
    let $ags := $dxf/dxf:metaData/dxf:userAuthorityGroups/dxf:userAuthorityGroup
    let $urs_version := max(for $date in $urs/@lastUpdated return xs:dateTime(util:fixup_date($date)))
    let $ags_version := max(for $date in $ags/@lastUpdated return xs:dateTime(util:fixup_date($date)))
    let $ur_oid := concat($oid,'.1')
    let $ag_oid := concat($oid,'.4')
    let $svs_urs := 
      <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$ur_oid}" version="{$group_version}" displayName="User Role at {$dhis_url}">
	<svs:ConceptList xml:lang="en-US" >
	  {
	    for $ur in ($urs,<userRole id='NOROLE' name='No Role'/>)
	    return <svs:Concept code="{$ur/@id}" displayName="{$ur/@name}" codeSystem="urn:{$dhis_url}/api/userRoles" />
	  }
	</svs:ConceptList>
      </svs:ValueSet>
    let $svs_ags := 
      <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$ag_oid}" version="{$group_version}" displayName="Authority Groups at {$dhis_url}">
	<svs:ConceptList xml:lang="en-US" >
	  {
	    for $ag in $ags
	    return <svs:Concept code="{$ag/@id}" displayName="{$ag/@name}" codeSystem="urn:{$dhis_url}/api/userRoles" />
	  }
	</svs:ConceptList>
      </svs:ValueSet>


    return ($svs_urs, $svs_ags)

let $svs_docs := ($svs_levels,$svs_groups,$svs_providers)


(:Insert everything we generated into the database :)

return (
  for $entity in ($entities,$providers)
  let $id := $entity/@entityID
  return 
    if (local-name($entity) = 'facility')
    then 
      let $existing_fac := $fac_dir/csd:facility[@entityID = $id]
      return
        if (not(exists($existing_fac)))
        then (insert node $entity into $fac_dir)
        else (replace node $existing_fac with $entity)
    else if (local-name($entity) = 'organization')
    then
      let $existing_org := $org_dir/csd:organization[@entityID = $id]
      return
        if (not(exists($existing_org)))
        then (insert node $entity into $org_dir)
        else (replace node $existing_org with $entity)
    else if (local-name($entity) = 'provider')
    then
      let $existing_prov := $prov_dir/csd:provider[@entityID = $id]
      return
        if (not(exists($existing_prov)))
        then (insert node $entity into $prov_dir)
        else (replace node $existing_prov with $entity)
    else ()
  ,
  for $svs_doc in $svs_docs return svs_lsvs:insert($csd_webconf:db,$svs_doc) 

)
