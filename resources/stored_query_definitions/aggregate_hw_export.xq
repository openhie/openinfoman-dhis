declare namespace csd = "urn:ihe:iti:csd:2013";
declare variable $careServicesRequest as item() external;

let $facilities := /csd:CSD/csd:facilityDirectory/csd:facility
let $providers := /csd:CSD/csd:providerDirectory/csd:providers
let $assName := $careServicesRequest/assigningAuthorityName
let $quater := '4';
let $year := substring-before(current-date(),'-')
let $month := substring-after(substring-after(current-date(),'-'),'-')
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
	let $facoid := $fac/@oid
	let $faccode := $fac/csd:otherID[@assigningAuthorityName= $assName ]/@code
	let $facProviders := $providers[csd:facilities/csd:facility/@oid=$facoid]    
	where $faccode   
	return 
        <dataValue period='{$period}' orgUnit='{$faccode}' dataElement='numProviders' value='{count($facProviders)}'/>
      }
    </dataValueSet>
  </dxf>