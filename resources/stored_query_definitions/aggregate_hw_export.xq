declare namespace csd = "urn:ihe:iti:csd:2013";
declare variable $careServicesRequest as item() external;

let $facilities := /csd:CSD/csd:facilityDirectory/csd:facility
let $active_providers := /csd:CSD/csd:providerDirectory/csd:provider[./csd:record/@status = "106-001"]

let $year := year-from-date(current-date())
let $month := month-from-date(current-date())
let $quarter := 
  if ($month < 4) then "1"
  else if ($month < 7) then "2"
  else if ($month < 10) then "3"
  else "4"
let $period := concat($year , 'Q',$quarter)

return 
  <dxf xmlns="http://dhis2.org/schema/dxf/2.0"> 
    <dataValueSet>
      {
	for $fac in $facilities
	let $fac_id := upper-case(string($fac/@entityID))
	let $facurn := substring($fac_id,10)
	let $fac_providers := $active_providers[./csd:facilities/csd:facility[upper-case(./@entityID)=$fac_id]]
	let $count := count($fac_providers)
	where $facurn  and $count > 0   
	return <dataValue period="{$period}" orgUnit="{$facurn}" dataElement="numProviders" value="{$count}" />
      }
    </dataValueSet>
  </dxf>