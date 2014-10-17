import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";


declare variable $careServicesRequest as item() external;


let $csd := dxf2csd:extract-directory($careServicesRequest/dxf,$careServicesRequest/oid)
let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($csd_webconf:db,$doc_name)
return  csd_dm:add($csd_webconf:db,$csd,$doc_name)

