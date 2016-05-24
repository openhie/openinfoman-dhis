import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";


declare variable $careServicesRequest as item() external;


let $csd := dxf2csd:extract-directory($careServicesRequest/csd:requestParams/dxf,$careServicesRequest/csd:requestParams/oid)
let $doc_name := string($careServicesRequest/@resource)
let $doc := csd_dm:open_document($doc_name)
return  csd_dm:add($csd,$doc_name)

