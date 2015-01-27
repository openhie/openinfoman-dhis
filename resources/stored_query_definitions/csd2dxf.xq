import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
declare namespace csd = "urn:ihe:iti:csd:2013";


declare variable $careServicesRequest as item() external;
let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)

let $facilities := $doc/csd:CSD/csd:facilityDirectory/csd:facility
let $svcs := $doc/csd:CSD/csd:serviceDirectory/csd:service
let $orgs := $doc/csd:CSD/csd:organizationDirectory/csd:organization


return 
    <metaData  xmlns="http://dhis2.org/schema/dxf/2.0"> 
      <organisationUnits>
        {
	  for $org in $orgs
	  return dxf2csd:make_org_from_org($doc,$org)
	}
        {
	  for $fac in $facilities
	  return dxf2csd:make_org_from_fac($doc,$fac)
	}
      </organisationUnits>
    </metaData>
