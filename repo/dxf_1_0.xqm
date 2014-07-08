module namespace dxf = "http://dhis2.org/schema/dxf/1.0";


declare function dxf:get_parent($doc,$orgUnit ) {
  let $child_id := $orgUnit/dxf:id/text()
  let $parent_id := $doc/dxf:dxf/dxf:organisationUnitRelationships/dxf:organisationUnitRelationship[./dxf:child/text() = $child_id]/dxf:parent/text()
  return $doc/dxf:dxf/dxf:organisationUnits/dxf:organisationUnit[./dxf:id/text()  = $parent_id]
  
};


declare function dxf:get_parents($doc,$orgUnit) {
  dxf:get_parents($doc,$orgUnit,())
};

declare function dxf:get_parents($doc,$orgUnit, $parents ) {
  let $parent := dxf:get_parent($doc,$orgUnit)
  return if (exists($parent)) then
    dxf:get_parents($doc,$parent,($orgUnit,$parents))
  else 
     ($orgUnit,$parents)
};

declare function dxf:orgunit_get_level($doc,$orgUnit ) {
  let $parents := dxf:get_parents($doc,$orgUnit)
  return count($parents)
};

declare function dxf:get_children($doc, $orgUnit){
  let $parent_id := $orgUnit/dxf:id/text()
  let $child_id := $doc/dxf:dxf/dxf:organisationUnitRelationships/dxf:organisationUnitRelationship[./dxf:parent/text() = $parent_id]/dxf:child/text()
  return $doc/dxf:dxf/dxf:organisationUnits/dxf:organisationUnit[./dxf:id/text()  = $child_id]
};


