import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";
import module namespace util = "https://github.com/openhie/openinfoman-dhis/util";
import module namespace functx = "http://www.functx.com";

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace csd = "urn:ihe:iti:csd:2013";
declare namespace dxf = "http://dhis2.org/csd/dxf/2.0";

declare variable $careServicesRequest as item() external; 

let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)
let $req_org_id :=    $careServicesRequest/csd:organization/@entityID 
let $req_ou_group_schemes:= distinct-values($careServicesRequest/orgUnitGroupSchemes/orgUnitGroupScheme/text())
  (:the organziation we want to import to:)



let $svcs := $doc/csd:CSD/csd:serviceDirectory/csd:service
let $orgs := 
  if (functx:all-whitespace($req_org_id))
  then dxf2csd:ensure_properly_ordered_orgs($doc/csd:CSD/csd:organizationDirectory/csd:organization)
  else 
    let $all_orgs := $doc/csd:CSD/csd:organizationDirectory/csd:organization
    let $org := $all_orgs[@entityID = $req_org_id]
    return 
      if (not(exists($org)))
      then ()
      else  (util:get_parent_orgs($all_orgs,$org),$org,util:get_child_orgs($all_orgs,$org))  (: this comes back properly ordered for DHIS2 import :)

let $facilities := 
  if (functx:all-whitespace($req_org_id))
  then $doc/csd:CSD/csd:facilityDirectory/csd:facility
  else  $doc/csd:CSD/csd:facilityDirectory/csd:facility[./csd:organizations/csd:organization = $orgs]

let $provs := $doc/csd:CSD/csd:providerDirectory/csd:provider



let $ou_oids := 
  for $dhis_url in distinct-values(($orgs/csd:record/@sourceDirectory,$facilities/csd:record/@sourceDirectory))
  let $namespace_uuid := util:uuid_generate($dhis_url,$util:namespace_uuid)
  let $oid := concat('2.25.',util:hexdec(util:uuid_generate('rootoid',$namespace_uuid)))	
  return $oid

    
return 
    <dxf:metaData>
      <dxf:users>
      {
	for $prov in $provs

	let $dhis_url := string(($prov/csd:record/@sourceDirectory)[1])
	let $dhis_id :=  ($prov/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/users") and @code="id"])[1]/text()	  
	let $namespace_uuid := util:uuid_generate($dhis_url,$util:namespace_uuid)
	let $oid := concat('2.25.',util:hexdec(util:uuid_generate('rootoid',$namespace_uuid)))	

	let $name := ($prov/csd:demographic/csd:name/csd:commonName)[1]/text()
	let $surname := ($prov/csd:demographic/csd:name/csd:surname)[1]/text()
	let $firstname := ($prov/csd:demographic/csd:name/csd:forename)[1]/text()
	let $username := dxf2csd:extract_uuid_from_entityid(string($prov/@entityID))
	let $phone := ($prov/csd:contactPoint/csd:codedType[@code="BP" and @codingScheme="urn:ihe:iti:csd:2013:contactPoint"])[1]/text()
	let $email := ($prov/csd:contactPoint/csd:codedType[@code="EMAIL" and @codingScheme="urn:ihe:iti:csd:2013:contactPoint"])[1]/text()
	let $ag_oid := concat($oid,'.4')
	let $ur_oid := concat($oid,'.1')
	let $urs := 
	   for $o_id in $prov/csd:codedType[@codingScheme = $ur_oid]
	   return <dxf:userRole id="{string($o_id/@code)}"/>
	let $uags := 
	   for $o_id in $prov/csd:codedType[@codingScheme = $ag_oid]
	   return <dxf:userAuthorityGroup id="{string($o_id/@code)}"/>
	let $p_orgs := 
	  for $org in $prov/csd:organizations/csd:organization
	  let $ou_uuid := 
	    ($facilities[@entityID = $org/@entityID]/csd:otherID[@assigningAuthorityName = concat($dhis_url,"/api/organisationUnits") and @code="uuid"])[1]/text()
	  return 
	    if (functx:all-whitespace($ou_uuid)) 
	    then () 
	    else  <dxf:organisationUnit uuid="{$ou_uuid}"/>

	      
	return
	  <dxf:user name="{$name}" >
	    {if (functx:all-whitespace($dhis_id)) then () else  @id}
	    <dxf:surname>{$surname}</dxf:surname>
	    <dxf:firstName>{$firstname}</dxf:firstName>
	    {if (functx:all-whitespace($email)) then () else <dxf:email>{$email}</dxf:email>}
	    {if (functx:all-whitespace($phone)) then () else <dxf:phoneNumber>{$email}</dxf:phoneNumber>}
	    <dxf:userCredenitals>
	      <dxf:username>{$username}</dxf:username> 
	      <dxf:userRoles>{$urs}</dxf:userRoles>
	      <dxf:userAuthorityGroups>{$uags}</dxf:userAuthorityGroups>
	    </dxf:userCredenitals>
	    <dxf:organisationUnits>
	      {$p_orgs}
	    </dxf:organisationUnits>
	  </dxf:user>
        }
      </dxf:users>

      <dxf:userRoles>
	{
	  let $oids := 
	    for $dhis_url in distinct-values($provs/csd:record/@sourceDirectory)
	    let $namespace_uuid := util:uuid_generate($dhis_url,$util:namespace_uuid)
	    let $oid := concat('2.25.',util:hexdec(util:uuid_generate('rootoid',$namespace_uuid)))	
	    return $oid
	  
	  return 
	  for $oid in $oids
            let $ur_oid := concat($oid,'.1')
	    let $svs := svs_lsvs:get_single_version_value_set($csd_webconf:db,$ur_oid)
	    return
	      if (not(exists($svs)))
	      then ()
              else 
		for $val in $svs//svs:concept
		return 
		  <dxf:userRole name="{$val/@displayName}" id="{$val/@code}">
		    <dxf:description>{string($val/@displayName)}</dxf:description>
		  </dxf:userRole>
	}
      </dxf:userRoles>
      <dxf:userAuthorityGroups>
	{
	  let $oids := 
	    for $dhis_url in distinct-values($provs/csd:record/@sourceDirectory)
	    let $namespace_uuid := util:uuid_generate($dhis_url,$util:namespace_uuid)
	    let $oid := concat('2.25.',util:hexdec(util:uuid_generate('rootoid',$namespace_uuid)))	
	    return $oid
	  
	  return 
	  for $oid in $oids
            let $ag_oid := concat($oid,'.4')
	    let $svs := svs_lsvs:get_single_version_value_set($csd_webconf:db,$ag_oid)
	    return
	      if (not(exists($svs)))
	      then ()
              else 
		for $val in $svs//svs:concept
		return 
		  <dxf:userAuthorityGroup name="{$val/@displayName}" id="{$val/@code}">
		    <dxf:description>{string($val/@displayName)}</dxf:description>
		  </dxf:userAuthorityGroup>
	}
      </dxf:userAuthorityGroups>





      <dxf:organisationUnits>
        {	 
	  for $org in $orgs
	  let $dhis_url := string($org/csd:record/@sourceDirectory)
	  let $dhis_uuid := ($org/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="uuid"])[1]/text()

	  let $level_code := string(($org/csd:codedType[@codingScheme=concat("urn:" ,$dhis_url,"/api/organisationUnitLevels")])[1]/@code)
	  let $level := 
	    if (not(functx:all-whitespace($level_code)))
	    then $level_code
	    else dxf2csd:get_level($doc,$org)

	  let $name := $org/csd:primaryName/text()

	  let $uuid := 
	    if (functx:all-whitespace($dhis_uuid))
	    then dxf2csd:extract_uuid_from_entityid(string($org/@entityID))
	    else string($dhis_uuid)

	  let $id_code := ($org/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="id"])[1]/text()
	  let $id :=
	    if (not(functx:all-whitespace($id_code)))
	    then $id_code
	    else dxf2csd:extract_id_from_entityid(string($org/@entityID)) 

	  let $created := dxf2csd:fixup_date($org/csd:record/@created)
	  let $lm := dxf2csd:fixup_date($org/csd:record/@updated)

	  let $porg_id := $org/csd:parent/@entityID
	  let $porg := $orgs[@entityID = $porg_id]
	  let $porg_dhis_uuid := ($porg/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="uuid"])[1]
	  let $parent :=
	    if (functx:all-whitespace($porg_id))
	    then () (: no parent :)
	    else if (not(functx:all-whitespace($porg_dhis_uuid)))
	    then <dxf:parent uuid="{$porg_dhis_uuid}"/>
  	    else <dxf:parent id="{dxf2csd:extract_id_from_entityid(string($porg_id))}"/>
	  let $avs :=
	    <dxf:attributeValues>
	      <dxf:attributeValue>
		<dxf:attribute name="entityID"/>
		<dxf:value>{$uuid}</dxf:value>
	      </dxf:attributeValue>
	    </dxf:attributeValues>
		    
	  return 
	    if (functx:all-whitespace($uuid))
	    then ()
	    else <organisationUnit 
              level="{$level}"
	      name="{$name}"
	      shortName="{substring($name,1,50)}"
	      uuid="{$uuid}" 
	      id="{$id}"
	      lastUpdated="{$lm}"
	      created="{$created}"
	      >
	    {$parent}
	    {$avs}
	    <dxf:openingDate>1970-01-01</dxf:openingDate> 
	  </organisationUnit>
	}
        {
	  for $fac in $facilities
	  (: remove the facilities that have already been created from a DHIS2 org unit:)
	  let $dhis_url := string($fac/csd:record/@sourceDirectory)
	  let $dhis_uuid := ($fac/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="uuid"])[1]
	  let $dhis_id := ($fac/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="id"])[1]
	  let $org := 
	    if (functx:all-whitespace($dhis_uuid))
	    then ()
	    else ($orgs[./csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="uuid" and ./text() = $dhis_uuid]])[1]
	  where not(exists($org))
	  return 
  	    let $level := dxf2csd:get_level($doc,$fac)
	    let $name := $fac/csd:primaryName/text()
	    let $uuid := 
	      if (functx:all-whitespace($dhis_uuid))
	      then dxf2csd:extract_uuid_from_entityid(string($fac/@entityID))
	      else string($dhis_uuid)
            let $id := 
	      if (functx:all-whitespace($dhis_id))
	      then dxf2csd:extract_id_from_entityid(string($fac/@entityID)) 
	      else string($dhis_id)
	    let $created := dxf2csd:fixup_date($fac/csd:record/@created)
	    let $lm := dxf2csd:fixup_date($fac/csd:record/@updated)

	    (: in CSD we can have multiple "parents" but not so DXF.  We just choose the first one    :)
	    let $org_id := ($orgs[@entityID = ($fac/csd:organizations/csd:organization)[1]/@entityID ])[1]
	    let $org := $orgs[@entity_id = $org_id]
	    let $org_dhis_uuid := ($org/csd:otherID[@assigningAuthorityName=concat($dhis_url,"/api/organisationUnits") and @code="uuid"])[1]
	    let $parent := 
	      if (functx:all-whitespace($org_id))
	      then ()  (: no parent :)
	      else if (not(functx:all-whitespace($org_dhis_uuid)))
	      then <dxf:parent id="{$org_dhis_uuid}"/>
	      else <dxf:parent id="{dxf2csd:extract_id_from_entityid(string($org_id))}"/>
	    let $avs :=
	      <dxf:attributeValues>
		<dxf:attributeValue>
		  <dxf:attribute name="entityID"/>
		  <dxf:value>{$uuid}</dxf:value>
		</dxf:attributeValue>
	      </dxf:attributeValues>
	
	   return 
	     if (functx:all-whitespace($uuid) )
	     then ()
	     else
	       <dxf:organisationUnit 
                 level="{$level}"
		 name="{$name}"
		 shortName="{substring($name,1,50)}"
		 uuid="{$uuid}" 
		 id="{$id}" 
		 lastUpdated="{$lm}"
		 created="{$created}"
		 >
		 {$parent}
		 {$avs}
		 <dxf:openingDate>1970-01-01</dxf:openingDate> 
	       </dxf:organisationUnit>
	   }
      </dxf:organisationUnits>

      <dxf:organisationUnitGroups>    
        {
	  let $ou_group_schemes := distinct-values((
	    $req_ou_group_schemes,
	    for $oid in $ou_oids return  concat($oid,'.3')
	      ))
	    
	  for $ou_group_scheme in $ou_group_schemes
	  let $types :=  svs_lsvs:get_single_version_value_set($csd_webconf:db,string($ou_group_scheme) )	  

	  let $org_unit_groups :=   
  	    for $concept in $types//svs:Concept
	    let $code := string($concept/@code)
	    let $scheme := string($concept/@codeSystem)
	    let $name := string($concept/@displayName)
	    return <dxf:organisationUnitGroup code="{$code}" name="{$name}" />

	  for $org_unit_group in $org_unit_groups
	  let $code := string($org_unit_group/@code)
	  let $scheme := string($org_unit_group/@codeSystem)
	  let $name := string($org_unit_group/@name)
	  let $short_name := substring(string($org_unit_group/@name),1,50)
	    return 
	    <dxf:organisationUnitGroup code="{$code}" name="{$name}" shortName="{$short_name}">
	      <dxf:organisationUnits>
		{
		  for $ent in ($facilities,$orgs)[./csd:codedType[@codingScheme = $scheme and @code = $code]]
		  let $uuid := dxf2csd:extract_uuid_from_entityid($ent/@entityID)
		  let $ent_name := $ent/csd:primaryName/text()
		  let $id := dxf2csd:extract_id_from_entityid(string($ent/@entityID)) 
		  return     
		     <dxf:organisationUnit uuid="{$uuid}" id="{$id}" name="{$ent_name}" />
		}
	      </dxf:organisationUnits>
	    </dxf:organisationUnitGroup>
	}
      </dxf:organisationUnitGroups>


      <dxf:organisationUnitLevels>
	{
	  
	  for $oid in $ou_oids
            let $level_oid := concat($oid,'.2')
	    let $svs := svs_lsvs:get_single_version_value_set($csd_webconf:db,$level_oid)
	    return
	      if (not(exists($svs)))
	      then ()
              else 
		for $val in $svs//svs:concept
		return 
		  <dxf:organisationUnitLevel name="{$val/@displayName}" id="{$val/@code}"/>

	}
       
      </dxf:organisationUnitLevels>

    </dxf:metaData>
