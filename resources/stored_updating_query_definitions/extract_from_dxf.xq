declare namespace csd = "urn:ihe:iti:csd:2013"; 

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace adx = "http://www.openhie.org/adx";

import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace functx = "http://www.functx.com";
import module namespace util = "https://github.com/openhie/openinfoman-dhis/util";
import module namespace async = "http://basex.org/modules/async";

declare variable $careServicesRequest as item() external; 



let $dhis_url := replace($careServicesRequest/URL/text(),'/+$','')
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
let $dataElements := $dxf/dxf:metaData/dxf:dataElements
let $catCombos := $dxf/dxf:metaData/dxf:categoryCombos
  
let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($doc_name)
let $org_dir := $doc/csd:CSD/csd:organizationDirectory
let $fac_dir := $doc/csd:CSD/csd:facilityDirectory
let $prov_dir := $doc/csd:CSD/csd:providerDirectory
let $srvc_dir := $doc/csd:CSD/csd:serviceDirectory

let $now := current-dateTime()



(: cache some node calculations :)
let $org_otherids := $org_dir/csd:organization/csd:otherID[@code='id']
let $orggroups_by_ou := $orgGroups/dxf:organisationUnits/dxf:organisationUnit

let $process_orgunit := function($orgUnit) {
  let $level := xs:integer($orgUnit/@level)
  let $id := $orgUnit/@id
  let $uuid := string($orgUnit/@uuid)

  let $displayName:=string($orgUnit/@name)
  let $org_code:=string($orgUnit/@code)
  let $pid:=string($orgUnit/dxf:parent/@id)

  let $lm := util:fixup_date($orgUnit/@lastUpdated)
  let $created := util:fixup_date($orgUnit/@created)
  let $groups := $orggroups_by_ou[@id = $id]/../..  (:clause should expect to match more than one. go to grandparent orgUnitGroup's :)
(:  let $groups := $orgGroups[./dxf:organisationUnits/dxf:organisationUnit[@id = $id]] :)
  let $group_codes := $groups/@code

  (:if there is an existing CSD UUID / entityID in DHIS2 we should keep it to referencer the org unit :)
  let $entity_uuid :=((($orgUnit/dxf:attributeValues/dxf:attributeValue[./dxf:attribute[@name='entityID']])[1])/dxf:value[1])/text()
  let $facEntityID := concat("urn:uuid:",util:uuid_generate(concat('facility:',$id),$namespace_uuid))
  let $orgEntityID :=
    if (not(functx:all-whitespace($entity_uuid)))
    then concat("urn:uuid:",$entity_uuid)
    else if (not(functx:all-whitespace($uuid)))
    then concat("urn:uuid:",$uuid)  
    else  concat("urn:uuid:",util:uuid_generate(concat('organization:',$id),$namespace_uuid))

          
  (:the parent org may be:
     1) in the dxf document being imported (highest precedence)
     2) in the destination csd document
     3) nowhere 

    in the case of 1) we want the parent's csd entity id to match the entity id of the parent org unit being imported
       case 1) happens if $porg is found
    in the case of 2) we want to use the parent id of the 
       in case is if $porg is not found but there is a csd:organization with the correct entity if in the dest. doc
    in the case of 3) we want to put it under our global root element for the import
    :)
    
  let $porg := ($orgUnits[@id=$pid])[1]
  let $parentEntityID :=     
    if (exists($porg))  (: there is a matching parent organization in the imported dxf document :)
    then  
      (:see if there is a DHIS2 attribute for the csd_entity ID :)
      let $p_entity_uuid :=((($porg/dxf:attributeValues/dxf:attributeValue[./dxf:attribute[@name='entityID']])[1])/dxf:value[1])/text()
      let $p_uuid := string($porg/@uuid)
      return
        if (not(functx:all-whitespace($p_entity_uuid))) 
        then concat("urn:uuid:",$p_entity_uuid)
	else if (not(functx:all-whitespace($p_uuid)))
        then concat("urn:uuid:",$p_uuid)
        else concat("urn:uuid:",util:uuid_generate(concat('organization:',$pid),$namespace_uuid))
    else (: we didn't find a matching parent organization in the dxf document, but may already be in target:)
      let $peorg := ($org_otherids[./text() = $pid])[1]/..  (: get the parent csd:organization element :)
(:      let $peorg := ($org_dir/csd:organization[./csd:otherID[@code='id' and ./text() = $pid]])[1] :)
      return
	if (exists($peorg))
        then $peorg/@entityID
        else ()

(:   let $puuid :=
     if (exists($porg))
     then  $porg/@uuid
     else if (exists($peorg))
     then  $peorg/@entityID
     else false
:)	  

  let $mainname := <csd:primaryName>{$displayName}</csd:primaryName>

  (:set up local identifiers:)
  let $other_ids := (
    <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnits" code="id">{string($id)}</csd:otherID>
    ,
    if (not(functx:all-whitespace($org_code)))
    then <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnits" code="code">{string($org_code)}</csd:otherID>
    else ()
    ,
    if (not(functx:all-whitespace($uuid)))
    then <csd:otherID assigningAuthorityName="{$dhis_url}/api/organisationUnits" code="uuid">{string($uuid)}</csd:otherID>
    else ()
    )

  (:set up codes:)
  let $level_code := <csd:codedType code="{$level}" codingScheme="urn:{$dhis_url}/api/organisationUnitLevels"/>
  let $group_cts :=
    for $group_code in $group_codes
    return <csd:codedType codingScheme="urn:{$dhis_url}/api/organisationUnitGroups" code="{$group_code}" />

  let $geo_data :=
     (
       util:get_geocode($orgUnit)
       ,util:get_shape($orgUnit)
     )
  let $name := <csd:primaryName>{string($orgUnit/@name)}</csd:primaryName>
  let $record :=  <csd:record created="{$created}" updated="{$lm}" status="Active" sourceDirectory="{$dhis_url}"/>
    

  (:first we extract all org units matching our facility conditions :)
  let $fac_srvcs :=
    if (not($do_srvcs))
    then ()
    else 
      (: get data sets that are associated to this org unit :)
      let $dsets := $dataSets/dxf:dataSet[dxf:organisationUnits/dxf:organisationUnit/@id = $id]
      return 
	(
	  (:each data set is a service :)
	  for $ds in $dsets
	  let $ds_id := string($ds/@id)
	  let $ds_uuid := string($ds/@uuid)
	  let $ds_entityID :=
	    if (not(functx:all-whitespace($ds_uuid)))
	    then concat("urn:uuid:",$ds_uuid)  
	    else  concat("urn:uuid:",util:uuid_generate(concat('service:',$ds_id),$namespace_uuid))
	  return <csd:service entityID="{$ds_entityID}"/>    
	  ,
	  (:each data element is a service :)
	  let $des :=
            for $dset in $dsets
	    return $dataElements/dxf:dataElement[@id = $dset/dxf:dataElements/dxf:dataElement/@id]
	  return 
            for $de in  $des
	    let $de_id := $de/@id
	    let $de_uuid := $de/@uuid
	    let $srvc_entity_id := 
	      if (not(functx:all-whitespace($de_uuid)))
	      then concat("urn:uuid:",$de_uuid)
	      else concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid))
	    return <csd:service entityID="{$srvc_entity_id}"/>
	  )

  let $fac_entity :=
    if (($group_codes = $facility_group_codes) or ( $level = $facility_levels)) 
    then
      <csd:facility entityID="{$facEntityID}">
	{$other_ids}
	{$level_code}
	{$group_cts}
	{$mainname}
	{$geo_data}
	<csd:organizations><csd:organization entityID="{$orgEntityID}">{$fac_srvcs}</csd:organization></csd:organizations>
	{$record}
      </csd:facility>
    else ()

  (:next we create an organization for each organisation unit.

    NOTE: this means that each organisation unit which matches as a facility will have two CSD 
          entities created a facility and an organization.  These two entities will have distinct
          UUIDs.  
   :)
     (:Should put in a CP to point geo codes for orgs as service delivery area :)

  let $org_entity :=
  <csd:organization entityID="{$orgEntityID}">
      {$other_ids}
      {$level_code}
      {$group_cts}
      {$mainname}
      {$geo_data}
      <csd:parent  entityID="{$parentEntityID}"/>
      {$record}
    </csd:organization>
  return ($org_entity,$fac_entity)

}


let $entities :=  
  let $orgunit_funcs :=     
    for $orgUnit in $orgUnits
    return function() {$process_orgunit($orgUnit)}
  return async:fork-join($orgunit_funcs)



let $process_users := function($user) {  
    let $id := string($user/@id)
    let $entityID := concat("urn:uuid:",util:uuid_generate(concat('provider:',$id),$namespace_uuid))
    let $ur_oid := concat($oid,'.1')
    let $ag_oid := concat($oid,'.4')
    let $uuid := string($user/@uuid)
    let $code:=string($user/dxf:userCredentials/@code)
    let $fore := $user/dxf:firstName/text()
    let $sur := $user/dxf:surname/text()
    let $email := $user/dxf:email/text()
    let $phone := $user/dxf:phoneNumber/text()
    let $lm := util:fixup_date($user/@lastUpdated)
    let $created := util:fixup_date($user/@created)
    let $urs := $user/dxf:userCredentials/dxf:userRoles/dxf:userRole
    let $ags := $user/dxf:userCredentials/dxf:userAuthorityGroups/dxf:userAuthorityGroup


    let $entity_uuid :=((($user/dxf:attributeValues/dxf:attributeValue[./dxf:attribute[@name='entityID']])[1])/dxf:value[1])/text()
    let $provEntityID :=
      if (not(functx:all-whitespace($entity_uuid)))
      then concat("urn:uuid:",$entity_uuid)
      else if (not(functx:all-whitespace($uuid)))
      then concat("urn:uuid:",$uuid)  
      else  concat("urn:uuid:",util:uuid_generate(concat('provider:',$id),$namespace_uuid))

    return 
    <csd:provider entityID="{$provEntityID}">
      <csd:otherID assigningAuthorityName="{$dhis_url}/api/users" code="id">{$id}</csd:otherID>
      {
	if (not(functx:all-whitespace($code)))
	then <csd:otherID assigningAuthorityName="{$dhis_url}/api/users" code="code">{$code}</csd:otherID>
        else ()
      }
      {
	if (not(functx:all-whitespace($uuid)))
	then <csd:otherID assigningAuthorityName="{$dhis_url}/api/users" code="uuid">{$uuid}</csd:otherID>
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
	  let $tid :=  $torg/@id
	  let $torg1 := ($orgUnits[@id=$tid])[1]
	  let $entity_uuid :=((($torg1/dxf:attributeValues/dxf:attributeValue[./dxf:attribute[@name='entityID']])[1])/dxf:value[1])/text()

    	  let $orgEntityID :=
	     if (not(functx:all-whitespace($entity_uuid)))
	     then concat("urn:uuid:" , $entity_uuid)
	     else concat("urn:uuid:",util:uuid_generate(concat('organization:',string($torg/@id)),$namespace_uuid))
          where  (exists($entities[@entityID = $orgEntityID]) or exists( $org_dir/csd:organization[@entityID = $orgEntityID]))
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
		  let $de_uuid := $de/@uuid
		  let $srvc_entity_id := 
		    if (not(functx:all-whitespace($de_uuid)))
		    then concat("urn:uuid:",$de_uuid)
		    else concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid))
	          return <csd:service entityID="{$srvc_entity_id}"/>
	  where  (exists($entities[@entityID = $facEntityID]) or exists( $org_dir/csd:facility[@entityID = $facEntityID]))
	  return <csd:facility entityID="{$facEntityID}">{$fac_srvcs}</csd:facility>
	  
	return 
	  if (count($facs) > 0) then
	  <csd:facilities>{$facs}</csd:facilities>
	  else ()
      }
    <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="{$dhis_url}"/>
    </csd:provider>
}


let $process_dataelements := function($de) {
    let $de_id := string($de/@id)
    let $name := string($de/@name)
    let $code := string($de/@code)
(:    let $entityID := concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid)) :)
    let $cat_id := $de/dxf:categoryCombo/@id
    let $cc :=  ($catCombos/dxf:categoryCombo[@id = $cat_id])[1]
    let $created := util:fixup_date($de/@created)
    let $lm := util:fixup_date($de/@lastUpdated)

    let $uuid := string($de/@uuid)
    let $entity_uuid :=((($de/dxf:attributeValues/dxf:attributeValue[./dxf:attribute[@name='entityID']])[1])/dxf:value[1])/text()
    let $srvcEntityID :=
      if (not(functx:all-whitespace($entity_uuid)))
      then concat("urn:uuid:",$entity_uuid)
      else if (not(functx:all-whitespace($uuid)))
      then concat("urn:uuid:",$uuid)  
      else  concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid))
 

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
      return <adx:disaggregator  id="{$doid}" refid="{$disag_id}" code="{$attr_name}">{$attr_display}</adx:disaggregator>

    return 
      <csd:service entityID="{$srvcEntityID}">
	<csd:primaryName>{$name}</csd:primaryName>
	<csd:otherID assigningAuthorityName="{$dhis_url}/api/dataElements" code="id">{$de_id}</csd:otherID>
	{     
	  if (not(functx:all-whitespace($uuid)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/dataElements" code="uuid">{string($uuid)}</csd:otherID>
	  else ()
	}
	{ if (not(functx:all-whitespace($code)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/dataElements" code="code">{$code}</csd:otherID>
	  else ()
	}

	{
	  if (count($disaggregatorSet) = 0) 
	  then ()
	  else 
	    <csd:extension urn="urn:http://www.openhie.org/adx" type="disaggreators">
	      <adx:disaggregatorSet id="{$cat_id}">
		{$disaggregatorSet}
	      </adx:disaggregatorSet>
	    </csd:extension>
	}
	{
	   <csd:extension urn="urn:http://www.dhis2.org/api/dataElement">
	     <dxf:dataElement shortname="{$de/@shortName}">
	       {$de/dxf:aggregationType}
	       {$de/dxf:dataDimension}
	       {$de/dxf:domainType}
	       {$de/dxf:type}
	       {$de/dxf:numberType}
	       {$de/dxf:aggregationOperator}
	       {$de/dxf:url}
	       {$de/dxf:zeroIsSignificant}
	     </dxf:dataElement>
	   </csd:extension>
	}

	<csd:record 
          created="{util:fixup_date($de/@created)}" 
          updated="{util:fixup_date($de/@lastUpdated)}" 
          status="Active" 
	  sourceDirectory="{$dhis_url}"/>        
      </csd:service>

}


let $process_dataset := function($ds) {
    let $ds_id := string($ds/@id)
    let $des := $ds/dxf:dataElements/dxf:dataElement
    let $name := string($ds/@name)
    let $s_name := string($ds/@shortName)
    let $pt := string($ds/dxf:periodType) 
    let $code := string($ds/@code)

    let $uuid := string($ds/@uuid)
    let $entityID :=
      if (not(functx:all-whitespace($uuid)))
      then concat("urn:uuid:",$uuid)  
      else  concat("urn:uuid:",util:uuid_generate(concat('service:',$ds_id),$namespace_uuid))
 
    return 
      <csd:service entityID="{$entityID}">
	<csd:primaryName>{$name}</csd:primaryName>
	<csd:otherID assigningAuthorityName="{$dhis_url}/api/dataSets" code="id">{$ds_id}</csd:otherID>
	{     
	  if (not(functx:all-whitespace($uuid)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/dataSets" code="uuid">{string($uuid)}</csd:otherID>
	  else ()
	}
	{ if (not(functx:all-whitespace($code)))
	  then <csd:otherID assigningAuthorityName="{$dhis_url}/api/dataSets" code="code">{$code}</csd:otherID>
	  else ()
	}

	{
	  if (count($des) = 0) 
	  then ()
	  else 
	    <csd:extension urn="urn:http://www.openhie.org/adx" type="dataSet">
	      {
              for $de in $des
	      let $de_id := string($de/@id)
	      let $uuid := string($de/@uuid)
	      let $entity_uuid :=((($de/dxf:attributeValues/dxf:attributeValue[./dxf:attribute[@name='entityID']])[1])/dxf:value[1])/text()
	      let $srvcEntityID :=
		if (not(functx:all-whitespace($entity_uuid)))
		then concat("urn:uuid:",$entity_uuid)
	        else if (not(functx:all-whitespace($uuid)))
		then concat("urn:uuid:",$uuid)  
	        else  concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid))
 	      return <csd:service entityID="{$srvcEntityID}"/>
	      }
	    </csd:extension>
	}

	<csd:record 
          created="{util:fixup_date($ds/@created)}" 
          updated="{util:fixup_date($ds/@lastUpdated)}" 
          status="Active" 
	  sourceDirectory="{$dhis_url}"/>        
      </csd:service>


(:    let $entityID := concat("urn:uuid:",util:uuid_generate(concat('service:',$de_id),$namespace_uuid)) :)

}



let $process_categories := function($category) {
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
}
	

(: create dhis2 users as health workers/providers if requested :)

let $providers := 
  if (not($do_hws))
  then ()
  else 
    let $prov_funcs := 
      for $user in $dxf/dxf:metaData/dxf:users/dxf:user 
      return function() {$process_users($user)}
    return async:fork-join($prov_funcs)


(: Create CSD Services for DHIS2 Data Elements :) 


let $srvcs := 
  if (not($do_srvcs))
  then ()
  else 
    (
    let $de_funcs := 
      for $de in ($dataElements/dxf:dataElement)
      return function() {$process_dataelements($de)}
    return async:fork-join($de_funcs)
    ,
    let $ds_funcs := 
      for $ds in $dataSets/dxf:dataSet
      return function() {$process_dataset($ds)}
    return async:fork-join($ds_funcs)
    )


(: Create an SVS list for each of the disaggregator sets in  the service :)
let $categories := $dxf/dxf:metaData/dxf:categories/dxf:category[dxf:dataDimensionType/text() = 'DISAGGREGATION']

let $svs_srvcs := 
  if (not($do_srvcs))
  then ()
  else
(:    for $category in $categories :)
    let $cat_funcs := 
       for $category in $categories[ @id  = $catCombos/dxf:categoryCombo/dxf:categories/dxf:category/@id]
       return function() {$process_categories($category)}
    return async:fork-join($cat_funcs)



(: Create an SVS list for the Org Unit Levels :)
	
let $level_oid := concat($oid,'.2')
let $levels := $dxf/dxf:metaData/dxf:organisationUnitLevels/dxf:organisationUnitLevel
let $level_version := max(for $date in $levels/@lastUpdated return xs:dateTime(util:fixup_date($date)))
let $svs_levels :=
  <svs:ValueSet  xmlns:svs="urn:ihe:iti:svs:2008" id="{$level_oid}" version="{$level_version}" displayName="Organisation Unit Levels for DHIS at {$dhis_url}">
    <svs:ConceptList xml:lang="en-US" >
      {
	for $level in $levels
	return <svs:Concept code="{$level/@level}" displayName="{$level/@name}" codeSystem="{$dhis_url}/api/organisationUnitLevels" />
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
	return <svs:Concept code="{$group/@code}" displayName="{$group/@name}" codeSystem="{$dhis_url}/api/organisationUnitGroups" />
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
	    return <svs:Concept code="{$ag/@id}" displayName="{$ag/@name}" codeSystem="{$dhis_url}/api/userAuthorityGroups" />
	  }
	</svs:ConceptList>
      </svs:ValueSet>


    return ($svs_urs, $svs_ags)

let $svs_docs := ($svs_levels,$svs_groups,$svs_providers,$svs_srvcs)

 
(:Insert everything we generated into the database :)

return (
  for $entity in ( $entities,$providers, $srvcs)
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
  for $svs_doc in $svs_docs return svs_lsvs:insert($svs_doc) 

)
