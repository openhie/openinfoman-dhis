module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0"; 


declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace csd = "urn:ihe:iti:csd:2013";
import module namespace functx = "http://www.functx.com";

declare variable $dxf2csd:namespace_uuid := "10df44d2-55f4-11e4-af21-705681a860b7";


declare function dxf2csd:oid_orgtype($oid_base){
  concat($oid_base,".1")
};
declare function dxf2csd:oid_hwtype($oid_base){
  concat($oid_base,".2") 
};



declare function dxf2csd:hexdec($hex) {
  let $zero := convert:binary-to-bytes('0')
  let $nine := convert:binary-to-bytes('9')
  let $a := convert:binary-to-bytes('A')
  let $e := convert:binary-to-bytes('E')
  let $u_hex := convert:binary-to-bytes(upper-case($hex))
  let $dec := $u_hex
    ! xs:decimal(if ( (. >= $zero and . <= $nine)) then (. - $zero) else if ( (. >= $a and . <= $e)) then (. - $a + 10) else ())
  return  fold-left($dec, 0, function($a, $b) { $a * 16 + $b }) 
};


declare function dxf2csd:tobits($tokens) {
  if (count($tokens) > 1)
  then  ( 
          bin:hex(concat($tokens[1],$tokens[2])),
          dxf2csd:tobits(subsequence($tokens,3))
        )
  else $tokens
};

declare function dxf2csd:generate_UUID_v3($name) {
  dxf2csd:generate_UUID_v3($name,$dxf2csd:namespace_uuid)
};

declare function dxf2csd:generate_UUID_v3($name,$namespace) {
  (: adapted from http://www.ietf.org/rfc/rfc4122.txt and https://gist.github.com/dahnielson/508447 :)
  let $bits := dxf2csd:tobits(functx:chars(translate($dxf2csd:namespace_uuid,'-','' )))
  let $s_bits := serialize($bits,map{'method':'raw'})
  let $hash := serialize(xs:hexBinary(hash:md5(concat($s_bits,  $name))))

  let $uuid :=
    concat(
      substring( $hash,1, 8)
      ,'-'
      ,substring( $hash,9, 4)  
      ,'-'
      ,xs:hexBinary(bin:or(bin:and(bin:hex(substring($hash, 13, 4)),bin:hex('0FFF')),bin:hex('3000')))
      ,'-'
       ,xs:hexBinary(bin:or( bin:and(bin:hex(substring( $hash,17, 4)) , bin:hex('3FFF')) , bin:hex('8000')))
      ,'-'
      ,substring( $hash,21, 12)
      )
  return $uuid
};


declare function dxf2csd:get_children($doc,$orgUnit) {
  let $id := $orgUnit/@id
  return $doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit[./dxf:parent/@id  = $id]
};



declare function dxf2csd:get_org_hws($doc,$orgUnit,$oid_base) {
  let $oid := dxf2csd:oid_hwtype($oid_base)    

  for $hw in $doc/dxf:metaData/dxf:users/dxf:user[count(./dxf:organisationUnits/dxf:organisationUnit[@id = $orgUnit/@id]) > 0]
  let $hwid := string($hw/@id)
  let $entityID := dxf2csd:generate_UUID_v3(concat('provider:',$hwid))
  let $role := ($hw/dxf:userCredentials/dxf:userAuthorityGroups/dxf:userAuthorityGroup/@id)[1]
  return 
    <csd:contact>
      {if (exists($role)) then <csd:codedType code="{$role}" codingScheme="{$oid}"/> else ()}
      <csd:provider entityID="{$entityID}"/>
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


declare function dxf2csd:orgUnit-to-fac($doc,$orgUnit,$oid_base)  {
  let $displayName:=string($orgUnit/@name)
  let $id:=string($orgUnit/@id)
  let $pid:=string($orgUnit/dxf:parent/@id)
  let $level :=   xs:integer($orgUnit/@level)
  let $lm := string($orgUnit/@lastUpdated)
  let $created := string($orgUnit/@created)
  let $oid := dxf2csd:oid_hwtype($oid_base)   
  let $entityID := dxf2csd:generate_UUID_v3(concat('facility:',$id))
  return 
  <csd:facility entityID="{$entityID}">
    <csd:otherID assigningAuthorityName="dhis.org:orgid" code="{$id}"/>
    <csd:codedType code="{$level}" codingScheme="{$oid}"/>
    <csd:primaryName>{$displayName}</csd:primaryName>
    { 
    if ($pid) then 
      let $pEntityID := dxf2csd:generate_UUID_v3(concat('organization:',$pid))
      return 
        <csd:organizations>
	  <csd:organization entityID="{$pEntityID}"/>
	</csd:organizations>
    else () 
    }
    {dxf2csd:get_org_hws($doc,$orgUnit,$oid_base)}
    {dxf2csd:get_geocode($doc,$orgUnit)}
    <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.dhis2.org"/>
  </csd:facility>
};

declare function dxf2csd:orgUnit-to-org($doc,$orgUnit,$oid_base)  {
  let $displayName:= string($orgUnit/@name)
  let $id:=string($orgUnit/@id)
  let $level := xs:integer($orgUnit/@level)
  let $lm := string($orgUnit/@lastUpdated)
  let $created := string($orgUnit/@created)
  let $entityID := dxf2csd:generate_UUID_v3(concat('organization:',$id))
  let $oid := dxf2csd:oid_orgtype($oid_base)
  return 
      <csd:organization entityID="{$entityID}">
	<csd:codedType code="{$level}" codingScheme="{$oid}"/>
	<csd:primaryName>{$displayName}</csd:primaryName>
	{
	  if ($level > 1) 
	    then
	    let $pid := string($orgUnit/dxf:parent/@id)
	    let $pEntityID := dxf2csd:generate_UUID_v3(concat('organization:',$pid))
	    return	<csd:parent entityID="{$pEntityID}"/>
	  else ()
        }
	{dxf2csd:get_org_hws($doc,$orgUnit,$oid_base)}
	{dxf2csd:get_geocode($doc,$orgUnit) (:Should put in a CP to point geo codes for orgs as service delivery area :)}
	<csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.dhis2.org"/>
      </csd:organization>

};



declare function dxf2csd:user-to-provider($doc,$user,$oid_base) {
  let $id := string($user/@id)
  let $entityID := dxf2csd:generate_UUID_v3(concat('provider:',$id))
  let $oid := dxf2csd:oid_hwtype($oid_base)
  let $fore := $user/dxf:firstName/text()
  let $sur := $user/dxf:surname/text()
  let $email := $user/dxf:email/text()
  let $phone := $user/dxf:phoneNumber/text()
  let $lm := string($user/@lastUpdated)
  let $created := string($user/@created)
  return 
  <csd:provider entityID="{$entityID}">
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
	      let $pEntityID := dxf2csd:generate_UUID_v3(concat('organization:',$orgid))
	      return <csd:organization entityID="{$pEntityID}"/>
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
		let $fEntityID :=dxf2csd:generate_UUID_v3( concat('facility:',$orgid))
		return <csd:facility entityID="{$fEntityID}"/>
	      }	    
	    </csd:facilities>
	  else ()
      }
      <csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.dhis2.org"/>
  </csd:provider>
};


declare function dxf2csd:extract-directory($doc,$oid_base) {
  let $level := 4
  let $orgUnits := $doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
  return 
  <csd:CSD xmlns:csd="urn:ihe:iti:csd:2013">
    <csd:organizationDirectory>    
    {
      for $orgUnit in $orgUnits
      let $lvl := xs:integer($orgUnit/@level)
      where (($lvl < $level) or (($lvl = $level) and (count(dxf2csd:get_children($doc, $orgUnit)) >0)))
      return dxf2csd:orgUnit-to-org($doc,$orgUnit,$oid_base)
    }
    </csd:organizationDirectory>
    <csd:serviceDirectory/>
    <csd:facilityDirectory>
      {
	for $orgUnit in $orgUnits
	let $lvl := xs:integer($orgUnit/@level)
	where ($lvl >= $level)
	return dxf2csd:orgUnit-to-fac($doc,$orgUnit,$oid_base)
      }
    </csd:facilityDirectory>
    <csd:providerDirectory>
      {
	for $user in $doc/dxf:metaData/dxf:users/dxf:user[count(./dxf:organisationUnits/dxf:organisationUnit) > 0]
	return dxf2csd:user-to-provider($doc,$user,$oid_base)
      }  
    </csd:providerDirectory>
  </csd:CSD>
};
