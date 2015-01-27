import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace svs_lsvs = "https://github.com/openhie/openinfoman/svs_lsvs";

declare namespace svs = "urn:ihe:iti:svs:2008";
declare namespace csd = "urn:ihe:iti:csd:2013";


declare variable $careServicesRequest as item() external;
let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)

let $facilities := $doc/csd:CSD/csd:facilityDirectory/csd:facility
let $svcs := $doc/csd:CSD/csd:serviceDirectory/csd:service
let $orgs := $doc/csd:CSD/csd:organizationDirectory/csd:organization


let $fac_type_ids := ("1.3.6.1.4.1.21367.200.103")


return 
    <metaData  xmlns="http://dhis2.org/schema/dxf/2.0"> 


      <organisationUnitGroups>
        {
	  for $fac_type_id in $fac_type_ids	  
	  let $fac_types :=  svs_lsvs:get_single_version_value_set($csd_webconf:db,string($fac_type_id) )	  
	  return
	    for $concept in $fac_types//svs:Concept
	    let $code := string($concept/@code)
	    let $scheme := string($concept/@codeSystem)
	    let $name := string($concept/@displayName)
	    return 
	    <organisationUnitGroup
              code="{$code}"
	      name="{$name}"
	      >
	      <organisationUnits>
		{
		  for $fac in $facilities[./csd:codedType[@codingScheme = $scheme and @code = $code]]
		  let $uuid := dxf2csd:extract_uuid_from_entityid($fac/@entityID)
		  let $fac_name := $fac/csd:primaryName/text()
		  return     
		     <organisationUnit uuid="{$uuid}4" name="{$fac_name}" />
		}
	      </organisationUnits>
	    </organisationUnitGroup>
	}
      </organisationUnitGroups>

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
