declare namespace csd = "urn:ihe:iti:csd:2013";
declare variable $careServicesRequest as item() external;

let $facilities := /csd:CSD/csd:facilityDirectory/csd:facility
let $providers := /csd:CSD/csd:providerDirectory/csd:provider
let $assName := $careServicesRequest/assigningAuthorityName/text()
let $quater := '4'
let $year := year-from-date(current-date())
let $month := month-from-date(current-date())
let $quater := 
  if ($month < 4) then "1"
  else if ($month < 7) then "2"
  else if ($month < 10) then "3"
  else "4"
let $period := concat('2013' , 'Q',$quater)

return 
  <dxf xmlns="http://dhis2.org/schema/dxf/2.0"> 
    <dataValueSet>
      {
	for $fac in $facilities
	let $facurn := $fac/@urn
	let $faccode := $fac/csd:otherID[@assigningAuthorityName= $assName ]/@code
	let $facProviders := $providers[./csd:facilities/csd:facility[@urn=$facurn]]
	let $count := count($facProviders)
	where $faccode  and $count > 0
	return 
        <dataValue period="{$period}" orgUnit="{$faccode}" dataElement="numProviders" value="{$count}" />
      }
    </dataValueSet>
  </dxf>