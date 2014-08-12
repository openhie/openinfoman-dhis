(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_org_levels_as_svs.xml DHIS_MetaData_to_orgtype_SVS.xq 

:)

declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace svs = "urn:ihe:iti:svs:2008";


let $oid_base := "2.268234768686152474523705575269868869248" (:decimal representaiton of  UUID:)
let $oid_orgtype:= concat($oid_base,".1")
let $list_name := "DHIS Sierra Leone Demo Data Organization Level"

let $version := concat(year-from-date(current-date()),'.',month-from-date(current-date()),'.',day-from-date(current-date()))

return 
<svs:ValueSet id="{$oid_orgtype}" version="{$version}" displayName="{$list_name}">
  <svs:ConceptList xml:lang="en-US">
    {
    for $level in /dxf:metaData/dxf:organisationUnitLevels/dxf:organisationUnitLevel
      return   <svs:Concept code="{$level/@level}" displayName="{$level/@name}" codeSystem="{$oid_orgtype}"/>
    }
  </svs:ConceptList>
</svs:ValueSet>


