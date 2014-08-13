module namespace dxf_conf = "http://dhis2.org/csd/config";

declare variable $dxf_conf:instance_name := "DHIS Sierra Leone Demo Data";
declare variable $dxf_conf:oid_base := "2.25.268234768686152474523705575269868869248"; (:decimal representaiton of  UUID.  Should be generated for each DHIS instances:)
declare variable $dxf_conf:urn_base := "urn:dhis.org:sierra-leone-demo";



(: DO NOT EDIT BELOW HERE :)

declare variable $dxf_conf:oid_orgtype:= concat($dxf_conf:oid_base,".1");
declare variable $dxf_conf:oid_hwtype:= concat($dxf_conf:oid_base,".2");
declare variable $dxf_conf:urn_base_fac := concat($dxf_conf:urn_base , ":csd:facility");
declare variable $dxf_conf:urn_base_org := concat($dxf_conf:urn_base , ":csd:organization");
declare variable $dxf_conf:urn_base_hw := concat($dxf_conf:urn_base , ":csd:provider");
