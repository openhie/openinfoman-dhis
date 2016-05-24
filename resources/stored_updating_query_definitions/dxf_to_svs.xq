import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";

declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace svs = "urn:ihe:iti:svs:2008";

declare variable $careServicesRequest as item() external;



let $version := concat(year-from-date(current-date()),'.',month-from-date(current-date()),'.',day-from-date(current-date()))

return (
  let $list_name := "DHIS2 Organization Unit Levels"
  let $id := dxf2csd:oid_orgtype($careServicesRequest/csd:requestParams/oid/text())
  let $svs := 
  <svs:ValueSet id="{$id}" version="{$version}" displayName="{$list_name}">
    <svs:ConceptList xml:lang="en-US">
      {
	for $level in $careServicesRequest/csd:requestParams/dxf/dxf:metaData/dxf:organisationUnitLevels/dxf:organisationUnitLevel
	return   <svs:Concept code="{$level/@level}" displayName="{$level/@name}" codeSystem="{$id}"/>
      }
    </svs:ConceptList>
  </svs:ValueSet>
  return svs_lsvs:insert($svs)
  ,
  let $list_name := "DHIS2 User Role List"
  let $id := dxf2csd:oid_hwtype($careServicesRequest/csd:requestParams/oid/text())
  let $svs := 
  <svs:ValueSet id="{$id}" version="{$version}" displayName="{$list_name}">
    <svs:ConceptList xml:lang="en-US">
      {
        for $role in $careServicesRequest/csd:requestParams/dxf/dxf:metaData/dxf:userRoles/dxf:userRole
        return   <svs:Concept code="{$role/@id}" displayName="{$role/@name}" codeSystem="{$id}"/>
      }
    </svs:ConceptList>
  </svs:ValueSet>
  return svs_lsvs:insert($svs)
)

