(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_org_levels_as_svs.xml DHIS_MetaData_to_orgtype_SVS.xq 

:)
import module namespace dxf2svs = "http://dhis2.org/svs/dxf/2.0";
dxf2svs:extract-organization-type(/)


