module namespace dxf_conf = "http://dhis2.org/csd/config";


(:
declare variable $dxf_conf:instance_name := "DHIS Sierra Leone Demo Data";
declare variable $dxf_conf:oid_base := "2.25.268234768686152474523705575269868869248"; 
declare variable $dxf_conf:urn_base := "urn:dhis.org:sierra-leone-demo";
:)

(: DO NOT EDIT BELOW HERE :)

declare function dxf_conf:oid_orgtype($oid_base){
  concat($oid_base,".1")
};
declare function dxf_conf:oid_hwtype($oid_base){
  concat($oid_base,".2") 
};
declare function dxf_conf:urn_base_fac ($urn_base){
  concat($urn_base , ":csd:facility")
};
declare function dxf_conf:urn_base_org($urn_base) {
  concat($urn_base , ":csd:organization")
};

declare function  dxf_conf:urn_base_hw($urn_base) {
   concat($urn_base , ":csd:provider")
};
