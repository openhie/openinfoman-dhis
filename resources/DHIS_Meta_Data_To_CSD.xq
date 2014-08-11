(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_metadata_as_csd.xml DHIS_Meta_Data_To_CSD.xq 

:)

declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace csd = "urn:ihe:iti:csd:2013";


let $get_children := function($doc,$orgUnit) {
  let $id := $orgUnit/@id
  return $doc/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit[./dxf:parent/@id  = $id]
}


let $urn_base := "urn:dhis.org:sierra-leone-demo"
let $urn_base_fac := concat($urn_base , ":csd:facility")
let $urn_base_org := concat($urn_base , ":csd:organization")

let $orgUnits := /dxf:metaData/dxf:organisationUnits/dxf:organisationUnit
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
	    <csd:codedType code="{$level}" codingScheme="{$urn_base}"/>
	    <csd:primaryName>{$displayName}</csd:primaryName>
	    {
	      if ($level > 1) 
	      then
		let $pid := string($orgUnit/dxf:parent/@id)
		return	<csd:parent urn="{$urn_base_org}:{$pid}"/>
	      else ()
             }
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
	   </csd:facility>
    }
  </csd:facilityDirectory>
  <csd:providerDirectory/>

</csd:CSD>


