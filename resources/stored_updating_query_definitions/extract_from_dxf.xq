declare namespace csd = "urn:ihe:iti:csd:2013"; 

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace adx = "http://www.openhie.org/adx";

import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace functx = "http://www.functx.com";
import module namespace util = "https://github.com/openhie/openinfoman-dhis/util";

declare variable $careServicesRequest as item() external; 



let $dhis_url := replace($careServicesRequest/URL/text(),'/+^','')
let $namespace_uuid := util:uuid_generate($dhis_url,$util:namespace_uuid)

let $dxf := $careServicesRequest/dxf
let $facility_group_codes := $careServicesRequest/groupCodes/groupCode/text()
let $facility_levels := $careServicesRequest/levels/level/text()
let $do_hws :=  ($careServicesRequest/usersAreHealthWorkers/text() = '1')
let $do_srvcs :=  ($careServicesRequest/dataelementsAreServices/text() = '1')

let $t_oid := $careServicesRequest/oid/text()  
let $oid :=      
  if (not(functx:all-whitespace($t_oid)))
  then $t_oid
  else 
    (:generate it from the uuid :)
    concat('2.25.',util:hexdec(util:uuid_generate('rootoid',$namespace_uuid)))

let $orgUnits := $dxf/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
let $orgGroups := $dxf/dxf:metaData/dxf:organisationUnitGroups/dxf:organisationUnitGroup
let $userRoles := $dxf/dxf:metaData/dxf:userRoles
let $dataSets := $dxf/dxf:metaData/dxf:dataSets

let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)
let $org_dir := $doc/csd:CSD/csd:organizationDirectory
let $fac_dir := $doc/csd:CSD/csd:facilityDirectory
let $prov_dir := $doc/csd:CSD/csd:providerDirectory
let $srvc_dir := $doc/csd:CSD/csd:serviceDirectory

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
	  let $tfac_id := $tfac/@id
    	  let $facEntityID := concat("urn:uuid:",util:uuid_generate(concat('facility:',string($tfac_id)),$namespace_uuid))
	  let $fac_srvcs := 
	    if (not($do_srvcs))
	    then ()
	    else 
	      for $r in $urs
	      let $r_id := $r/@id
	      let $role := ($userRoles/dxf:userRole[@id = $r_id])[1]
	      for $ds_ref in $role/dxf:dataSets/dxf:dataSet
	        let $ds_id := $ds_ref/@id
		let $ds := ($dataSets/dxf:dataSet[@id = $ds_id])[1]
		let $ds_orgunit := $ds/dxf:organisationUnits/dxf:organisationUnit[@id = $tfac_id]
		for $de in  $ds_orgunit/../../dxf:dataElements/dxf:dataElement
		  let $de_id := $de/@id
		  let $srvc_entity_id := concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid))
	          return <csd:service entityID="{$srvc_entity_id}"/>
          where  (exists($entities[@entityID = $facEntityID]))
	  return <csd:facility entityID="{$facEntityID}">{$fac_srvcs}</csd:facility>
	  
	return 
	  if (count($facs) > 0) then
	  <csd:facilities>{$facs}</csd:facilities>
	  else ()
      }
    <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="{$dhis_url}"/>
    </csd:provider>


(: Create CSD Services for DHIS2 Data Elements :) 

let $catCombos := $dxf/dxf:metaData/dxf:categoryCombos
let $srvcs := 
  if (not($do_srvcs))
  then ()
  else 
    for $de in ($dxf/dxf:metaData/dxf:dataElements/dxf:dataElement)
    let $de_id := string($de/@id)
    let $name := string($de/@name)
    let $code := string($de/@code)
    let $entityID := concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid))
    let $cat_id := $de/dxf:categoryCombo/@id
    let $cc :=  ($catCombos/dxf:categoryCombo[@id = $cat_id])[1]
    let $created := util:fixup_date($de/@created)
    let $lm := util:fixup_date($de/@lastUpdated)

(:
    let $cc_id := $cc/@id
    let $cc_oid := string-join(for $cp in string-to-codepoints(string($cc_id)) return string($cp))
:)  
    let $disaggregatorSet := 
      for $disag in  $cc/dxf:categories/dxf:category
      let $disag_id := $disag/@id
      let $disag_code := $disag/@code
      let $disag_oid := string-join(for $cp in string-to-codepoints(string($disag_code)) return string($cp))
      let $doid :=  concat($oid , '.6.' , $disag_oid )
      let $attr_display:= string($disag/@name)
      let $attr := $disag_code
	(:need to be able to make it into an attribute for compatibility with ADX :)
(:
        try {
	  attribute {xs:string($disag_code)} {()}
	} catch * {
	  ''
	}
:)
      let $attr_name := string($attr)
      where ( not(functx:all-whitespace($attr_name))  and  not($attr_display = 'default')) 
      return <adx:disaggregator id="{$doid}" name="{$attr_name}">{$attr_display}</adx:disaggregator>

    return 
      <csd:service entityID="{$entityID}">
	<csd:primaryName>{$name}</csd:primaryName>
	<csd:codedType codingScheme="urn:{$dhis_url}/api/dataElement" code="{$de/dxf:type/text()}" /> 
	<csd:otherID assigningAuthorityName="{$dhis_url}/api/dataElement" code="id">{$de_id}</csd:otherID>
	{ if (not(functx:all-whitespace($code)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/dataElement" code="code">{$code}</csd:otherID>
	  else ()
	}
	{
	  if (count($disaggregatorSet) = 0) 
	  then ()
	  else 
	    <csd:extension urn="urn:http://www.openhie.org/adx" type="disaggreators">
	      <adx:disaggregatorSet>
		{$disaggregatorSet}
	      </adx:disaggregatorSet>
	    </csd:extension>
	}
	<csd:record 
          created="{$de/@created}" 
          updated="{$de/@lastUpdated}" 
          status="Active" 
	  sourceDirectory="{$dhis_url}"/>        
      </csd:service>


(: Create an SVS list for each of the disaggregator sets in  the service :)
let $categories := $dxf/dxf:metaData/dxf:categories/dxf:category[dxf:dataDimensionType/text() = 'DISAGGREGATION']

let $svs_srvcs := 
  if (not($do_srvcs))
  then ()
  else
(:    for $category in $categories :)
    for $category in $categories[ @id  = $catCombos/dxf:categoryCombo/dxf:categories/dxf:category/@id]
    let $disag_code := string($category/@code)
    let $disag_oid := string-join(for $cp in string-to-codepoints(string($disag_code)) return string($cp))      
    let $disag_date := xs:dateTime(substring(string($category/@lastUpdated),1,19))
    let $disag_name := string($category/@name)
    let $disag_id := string($category/@id)
    let $svs_vals_0 :=    
      for $catOption in $category/dxf:categoryOptions/dxf:categoryOption
      let $disag_opt_date := xs:dateTime(substring(string($catOption/@lastUpdated),1,19))
      let $disag_opt_name := string($catOption/@name)
      let $date := max(($disag_date,$disag_date,$disag_opt_date))
      where (not((functx:all-whitespace($disag_opt_name)) )) 
      return <svs:Concept code="{$disag_opt_name}" displayName="{$disag_opt_name}" codeSystem="{$dhis_url}/adx/disaggregators/{$disag_code}" lu="{$date}"/>

    let $date := max(( for $d in $svs_vals_0/@lu return xs:dateTime($d)))
    let $svs_vals_1 := functx:remove-attributes-deep($svs_vals_0,'lu')
    
    let $oid :=  concat($oid , '.6.' , $disag_oid)	

    let $attr := $disag_code

    let $svs_doc :=
      <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$oid}" version="{$date}" displayName="[ADX {$disag_code}] Disaggregator for {$disag_name}. ( {$disag_id
} ) Published {$date}.  ">
	<svs:ConceptList xml:lang="en-US" >{$svs_vals_1}</svs:ConceptList>
      </svs:ValueSet>
    where ( not(functx:all-whitespace($disag_code))  and not($disag_name = 'default'))   
    return $svs_doc



(: Create an SVS list for the Org Unit Levels :)
	
let $level_oid := concat($oid,'.2')
let $levels := $dxf/dxf:metaData/dxf:organisationUnitLevels/dxf:organisationUnitLevel
let $level_version := max(for $date in $levels/@lastUpdated return xs:dateTime(util:fixup_date($date)))
let $svs_levels :=
  <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$level_oid}" version="{$level_version}" displayName="Organisation Unit Levels for DHIS at {$dhis_url}">
    <svs:ConceptList xml:lang="en-US" >
      {
	for $level in $levels
	return <svs:Concept code="{$level/@level}" displayName="{$level/@name}" codeSystem="{$dhis_url}/api/organisationUnitLevel" />
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
	return <svs:Concept code="{$group/@code}" displayName="{$group/@name}" codeSystem="{$dhis_url}/api/organisationUnitGroup" />
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
	    return <svs:Concept code="{$ur/@id}" displayName="{$ur/@name}" codeSystem="{$dhis_url}/api/userRoles" />
	  }
	</svs:ConceptList>
      </svs:ValueSet>
    let $svs_ags := 
      <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$ag_oid}" version="{$group_version}" displayName="Authority Groups at {$dhis_url}">
	<svs:ConceptList xml:lang="en-US" >
	  {
	    for $ag in $ags
	    return <svs:Concept code="{$ag/@id}" displayName="{$ag/@name}" codeSystem="{$dhis_url}/api/userRoles" />
	  }
	</svs:ConceptList>
      </svs:ValueSet>


    return ($svs_urs, $svs_ags)

let $svs_docs := ($svs_levels,$svs_groups,$svs_providers,$svs_srvcs)

 
(:Insert everything we generated into the database :)

return (
  for $entity in ($entities,$providers, $srvcs)
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
    else if (local-name($entity) = 'service')
    then
      let $existing_srvc := $srvc_dir/csd:service[@entityID = $id]
      return
        if (not(exists($existing_srvc)))
        then (insert node $entity into $srvc_dir)
        else (replace node $existing_srvc with $entity)

    else (insert node $entity into /)
  ,
  for $svs_doc in $svs_docs return svs_lsvs:insert($csd_webconf:db,$svs_doc) 

)
