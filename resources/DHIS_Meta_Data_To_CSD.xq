(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_metadata_as_csd.xml DHIS_Meta_Data_To_CSD.xq 

:)

declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace csd = "urn:ihe:iti:csd:2013";




let $urn_base := "urn:dhis.org:sierra-leone-demo"
let $oid_base := "2.268234768686152474523705575269868869248" (:decimal representaiton of  UUID:)
let $oid_orgtype:= concat($oid_base,".1") (: cross references org level :)
let $oid_hwtype:= concat($oid_base,".2") (: cross references authority group :)
let $urn_base_fac := concat($urn_base , ":csd:facility")
let $urn_base_org := concat($urn_base , ":csd:organization")
let $urn_base_hw := concat($urn_base , ":csd:provider")

let $get_children := function($doc,$orgUnit) {
  let $id := $orgUnit/@id
  return $doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit[./dxf:parent/@id  = $id]
}


let $get_org_hws := function($doc,$orgUnit) {
  for $hw in $doc/dxf:metaData/dxf:users/dxf:user[count(./dxf:organisationUnits/dxf:organisationUnit[@id = $orgUnit/@id]) > 0]
  let $hwid := string($hw/@id)
  return 
  <csd:contact>
    <csd:provider urn="{$urn_base_hw}:{$hwid}"/>
  </csd:contact>
}

let $get_geocode := function($doc,$orgUnit) {
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
}



let $orgUnits := /dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
let $orgUsers := /dxf:metaData/dxf:users/dxf:user[count(./dxf:organisationUnits/dxf:organisationUnit) > 0]
return 
<csd:CSD xmlns:csd="urn:ihe:iti:csd:2013">
  <csd:organisationDirectory>
    {
      for $orgUnit in $orgUnits
      let $displayName:= string($orgUnit/@name)
      let $id:=string($orgUnit/@id)
      let $level := xs:integer($orgUnit/@level)
      return 
	if (($level < 4) or (($level = 4) and (count($get_children(/, $orgUnit)) >0))) 
	then
  	  <csd:organization urn="{$urn_base_org}:{$id}">
	    <csd:codedType code="{$level}" codingScheme="{$oid_orgtype}"/>
	    <csd:primaryName>{$displayName}</csd:primaryName>
	    {
	      if ($level > 1) 
	      then
		let $pid := string($orgUnit/dxf:parent/@id)
		return	<csd:parent urn="{$urn_base_org}:{$pid}"/>
	      else ()
             }
	     {$get_org_hws(/,$orgUnit)}
	    {$get_geocode(/,$orgUnit) (:Should put in a CP to point geo codes for orgs as service delivery area :)}
	   </csd:organization>
        else () 
      }
  </csd:organisationDirectory>
  <csd:serviceDirectory/>
  <csd:facilityDirectory>
    {
      for $orgUnit in $orgUnits
      let $displayName:=string($orgUnit/@name)
      let $id:=string($orgUnit/@id)
      let $pid:=string($orgUnit/dxf:parent/@id)
      let $level :=   xs:integer($orgUnit/@level)
      where ($level > 3) 
      return 
	   <csd:facility oid="{$urn_base_fac}:{$id}">
	    <csd:codedType code="{$level}" codingScheme="{$urn_base}"/>
	    <csd:primaryName>{$displayName}</csd:primaryName>
	    { if ($pid) then 
	      <csd:organizations>
	       <csd:organization urn="{$urn_base_org}:{$pid}"/>
	      </csd:organizations>
	      else () 
	    }
	    {$get_org_hws(/,$orgUnit)}
	    {$get_geocode(/,$orgUnit)}
	   </csd:facility>
    }
  </csd:facilityDirectory>
  <csd:providerDirectory>
   {
     for $user in $orgUsers 
     let $id := string($user/@id)
     let $urn := concat($urn_base_hw , ':',$id)     
     let $fore := $user/dxf:firstName/text()
     let $sur := $user/dxf:surname/text()
     let $email := $user/dxf:email/text()
     let $phone := $user/dxf:phoneNumber/text()
     return 
      <csd:provider urn="{$urn}">
         {
	   for $ag in $user/dxf:userCredentials/dxf:userAuthorityGroups/dxf:userAuthorityGroup
	   return 
           <csd:codedType code="{$ag/@id}" codingScheme="{$oid_hwtype}"/>
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
	 <csd:organizations>
	   {
	     for $org in $user/dxf:organisationUnits/dxf:organisationUnit
	     let $orgid := string($org/@id)
	     return <csd:organization urn="{$urn_base_org}:{$orgid}"/>
	   }
	 </csd:organizations>

      </csd:provider>

   }
  </csd:providerDirectory>


</csd:CSD>


