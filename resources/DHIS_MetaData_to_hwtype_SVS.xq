(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_org_levels_as_svs.xml DHIS_MetaData_to_hwtype_SVS.xq 

:)

declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace svs = "urn:ihe:iti:svs:2008";


let $oid_base := "2.268234768686152474523705575269868869248" (:decimal representaiton of  UUID:)
let $oid_hwtype:= concat($oid_base,".2")
let $list_name := "DHIS Sierra Leone Demo Data Health Worker Type"

let $version := concat(year-from-date(current-date()),'.',month-from-date(current-date()),'.',day-from-date(current-date()))

return 
<svs:ValueSet id="{$oid_hwtype}" version="{$version}" displayName="{$list_name}">
  <svs:ConceptList xml:lang="en-US">
    {
    for $role in /dxf:metaData/dxf:userRoles/dxf:userRole
      return   <svs:Concept code="{$role/@id}" displayName="{$role/@name}" codeSystem="{$oid_hwtype}"/>
    }
  </svs:ConceptList>
</svs:ValueSet>


