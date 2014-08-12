(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_org_levels_as_svs.xml DHIS_MetaData_to_orgtype_SVS.xq 

:)
import module namespace dxf_conf = "http://dhis2.org/csd/config" at "DHIS_config.xqm";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace svs = "urn:ihe:iti:svs:2008";



let $list_name := concat($dxf_conf:instance_name, " Organization Level")

let $version := concat(year-from-date(current-date()),'.',month-from-date(current-date()),'.',day-from-date(current-date()))

return 
<svs:ValueSet id="{$dxf_conf:oid_orgtype}" version="{$version}" displayName="{$list_name}">
  <svs:ConceptList xml:lang="en-US">
    {
    for $level in /dxf:metaData/dxf:organisationUnitLevels/dxf:organisationUnitLevel
      return   <svs:Concept code="{$level/@level}" displayName="{$level/@name}" codeSystem="{$dxf_conf:oid_orgtype}"/>
    }
  </svs:ConceptList>
</svs:ValueSet>


