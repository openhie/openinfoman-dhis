import module namespace csd_dm =  "https://github.com/openhie/openinfoman/csd_dm";
import module namespace csd_bl =  "https://github.com/openhie/openinfoman/csd_bl";
declare namespace csd = "urn:ihe:iti:csd:2013";

let $doc := csd_dm:open_document('TZOU')
let $all_orgs := $doc/csd:CSD/csd:organizationDirectory/csd:organization
let $org_ref := <csd:organization entityID="urn:uuid:dd65dd2b-0c1e-46b6-bcbc-6eb3be0c388f"/>
let $org := $all_orgs[@entityID = $org_ref/@entityID]

return (csd_bl:get_parent_orgs($all_orgs,$org),$org, csd_bl:get_child_orgs($all_orgs,$org)   )