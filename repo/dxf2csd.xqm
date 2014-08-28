module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0"; 


declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace csd = "urn:ihe:iti:csd:2013";


declare function dxf2csd:oid_orgtype($oid_base){
  concat($oid_base,".1")
};
declare function dxf2csd:oid_hwtype($oid_base){
  concat($oid_base,".2") 
};
declare function dxf2csd:urn_base_fac ($urn_base){
  concat($urn_base , ":csd:facility")
};
declare function dxf2csd:urn_base_org($urn_base) {
  concat($urn_base , ":csd:organization")
};

declare function  dxf2csd:urn_base_hw($urn_base) {
   concat($urn_base , ":csd:provider")
};


declare function dxf2csd:get_children($doc,$orgUnit) {
  let $id := $orgUnit/@id
  return $doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit[./dxf:parent/@id  = $id]
};



declare function dxf2csd:get_org_hws($doc,$orgUnit,$urn_base,$oid_base) {
  let $oid := dxf2csd:oid_hwtype($oid_base)    

  for $hw in $doc/dxf:metaData/dxf:users/dxf:user[count(./dxf:organisationUnits/dxf:organisationUnit[@id = $orgUnit/@id]) > 0]
  let $hwid := string($hw/@id)
  let $urn := concat(dxf2csd:urn_base_hw($urn_base),':',$hwid)
  let $role := ($hw/dxf:userCredentials/dxf:userAuthorityGroups/dxf:userAuthorityGroup/@id)[1]
  return 
    <csd:contact>
      {if (exists($role)) then <csd:codedType code="{$role}" codingScheme="{$oid}"/> else ()}
      <csd:provider urn="{$urn}"/>
    </csd:contact>
};


declare  function dxf2csd:get_geocode($doc,$orgUnit) {
  let $ft := $orgUnit/dxf:featureType/text()
  let $coord := $orgUnit/dxf:coordinates/text()
  let $lat := substring-after(substring-before($coord,','),'[')
  let $long := substring-after(substring-before($coord,']'),',')
    
  return 
    if ($ft = 'Point' and $lat and $long) 
      then
      <csd:geocode>
	<csd:latitude>{$lat}</csd:latitude>
	<csd:longitude>{$long}</csd:longitude>
      </csd:geocode>
    else ()
};


declare function dxf2csd:orgUnit-to-fac($doc,$orgUnit,$urn_base,$oid_base)  {
  let $displayName:=string($orgUnit/@name)
  let $id:=string($orgUnit/@id)
  let $pid:=string($orgUnit/dxf:parent/@id)
  let $level :=   xs:integer($orgUnit/@level)
  let $lm := string($orgUnit/@lastUpdated)
  let $created := string($orgUnit/@created)
  let $oid := dxf2csd:oid_hwtype($oid_base)   
  let $urn := concat(dxf2csd:urn_base_fac($urn_base),':',$id)
  return 
  <csd:facility urn="{$urn}">
    <csd:otherID assigningAuthorityName="dhis.org:orgid" code="{$id}"/>
    <csd:codedType code="{$level}" codingScheme="{$oid}"/>
    <csd:primaryName>{$displayName}</csd:primaryName>
    { 
    if ($pid) then 
      let $purn := concat(dxf2csd:urn_base_org($urn_base),':',$pid)
      return 
        <csd:organizations>
	  <csd:organization urn="{$purn}"/>
	</csd:organizations>
    else () 
    }
    {dxf2csd:get_org_hws($doc,$orgUnit,$urn_base,$oid_base)}
    {dxf2csd:get_geocode($doc,$orgUnit)}
    <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.dhis2.org"/>
  </csd:facility>
};

declare function dxf2csd:orgUnit-to-org($doc,$orgUnit,$urn_base,$oid_base)  {
  let $displayName:= string($orgUnit/@name)
  let $id:=string($orgUnit/@id)
  let $level := xs:integer($orgUnit/@level)
  let $lm := string($orgUnit/@lastUpdated)
  let $created := string($orgUnit/@created)
  let $urn := concat(dxf2csd:urn_base_org($urn_base),':',$id)
  let $oid := dxf2csd:oid_orgtype($oid_base)
  return 
      <csd:organization urn="{$urn}">
	<csd:codedType code="{$level}" codingScheme="{$oid}"/>
	<csd:primaryName>{$displayName}</csd:primaryName>
	{
	  if ($level > 1) 
	    then
	    let $pid := string($orgUnit/dxf:parent/@id)
	    let $purn := concat(dxf2csd:urn_base_org($urn_base),':',$pid)
	    return	<csd:parent urn="{$purn}"/>
	  else ()
        }
	{dxf2csd:get_org_hws($doc,$orgUnit,$urn_base,$oid_base)}
	{dxf2csd:get_geocode($doc,$orgUnit) (:Should put in a CP to point geo codes for orgs as service delivery area :)}
	<csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.dhis2.org"/>
      </csd:organization>

};



declare function dxf2csd:user-to-provider($doc,$user,$urn_base,$oid_base) {
  let $id := string($user/@id)
  let $urn := concat(dxf2csd:urn_base_hw($urn_base) , ':',$id)     
  let $oid := dxf2csd:oid_hwtype($oid_base)
  let $fore := $user/dxf:firstName/text()
  let $sur := $user/dxf:surname/text()
  let $email := $user/dxf:email/text()
  let $phone := $user/dxf:phoneNumber/text()
  let $lm := string($user/@lastUpdated)
  let $created := string($user/@created)
  return 
  <csd:provider urn="{$urn}">
    {
      for $ag in $user/dxf:userCredentials/dxf:userAuthorityGroups/dxf:userAuthorityGroup
      return 
      <csd:codedType code="{$ag/@id}" codingScheme="{$oid}"/>
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
        let $level :=  string($doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit[@id = $torg/@id]/@level)
	where ($level = "1" or $level = "2" or $level = "3")
	return $torg
	         
      return 
	if (count($orgs) > 0) then
	  <csd:organizations>
	    {
	      for $org in $orgs
	      let $orgid := string($org/@id)
	      let $purn := concat(dxf2csd:urn_base_org($urn_base),':',$orgid)
	      return <csd:organization urn="{$purn}"/>
	    }
	  
	  </csd:organizations>
	else ()
     }
     {
       let $tfacs := $user/dxf:organisationUnits/dxf:organisationUnit
       let $facs := 
         for $tfac in $tfacs
	 let $level :=  string($doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit[@id = $tfac/@id]/@level)
	 where ($level = "4" or $level = "5")
	 return $tfac

	return if (count($facs) > 0)
	  then
	    <csd:facilities>
	      {
		for $org in $facs
		let $orgid := string($org/@id)
		let $furn := concat(dxf2csd:urn_base_fac($urn_base),':',$orgid)
		return <csd:facility urn="{$furn}"/>
	      }	    
	    </csd:facilities>
	  else ()
      }
      <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.dhis2.org"/>
  </csd:provider>
};


declare function dxf2csd:extract-directory($doc,$urn_base,$oid_base) {
  let $level := 4
  let $orgUnits := $doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
  return 
  <csd:CSD xmlns:csd="urn:ihe:iti:csd:2013">
    <csd:organizationDirectory>    
    {
      for $orgUnit in $orgUnits
      let $lvl := xs:integer($orgUnit/@level)
      where (($lvl < $level) or (($lvl = $level) and (count(dxf2csd:get_children($doc, $orgUnit)) >0)))
      return dxf2csd:orgUnit-to-org($doc,$orgUnit,$urn_base,$oid_base)
    }
    </csd:organizationDirectory>
    <csd:serviceDirectory/>
    <csd:facilityDirectory>
      {
	for $orgUnit in $orgUnits
	let $lvl := xs:integer($orgUnit/@level)
	where ($lvl >= $level)
	return dxf2csd:orgUnit-to-fac($doc,$orgUnit,$urn_base,$oid_base)
      }
    </csd:facilityDirectory>
    <csd:providerDirectory>
      {
	for $user in $doc/dxf:metaData/dxf:users/dxf:user[count(./dxf:organisationUnits/dxf:organisationUnit) > 0]
	return dxf2csd:user-to-provider($doc,$user,$urn_base,$oid_base)
      }  
    </csd:providerDirectory>
  </csd:CSD>
};
