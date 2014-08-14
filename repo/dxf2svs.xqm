module namespace dxf2svs = "http://dhis2.org/svs/dxf/2.0"; 


import module namespace dxf_conf = "http://dhis2.org/csd/config";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace svs = "urn:ihe:iti:svs:2008";


declare function dxf2svs:extract-health-worker-type($doc) {

  let $list_name := concat($dxf_conf:instance_name, " Health Worker Type")

  let $version := concat(year-from-date(current-date()),'.',month-from-date(current-date()),'.',day-from-date(current-date()))

  return 
  <svs:ValueSet id="{$dxf_conf:oid_hwtype}" version="{$version}" displayName="{$list_name}">
    <svs:ConceptList xml:lang="en-US">
      {
	for $role in $doc/dxf:metaData/dxf:userRoles/dxf:userRole
	return   <svs:Concept code="{$role/@id}" displayName="{$role/@name}" codeSystem="{$dxf_conf:oid_hwtype}"/>
      }
    </svs:ConceptList>
  </svs:ValueSet>
};



