(:
To use:
  basex  -i /path/to/source/metaData.xml -o /tmp/dhis_metadata_as_csd.xml DHIS_Meta_Data_To_CSD.xq 

:)
import module namespace dxf2csd = "http://dhis2.org/csd/dxf/2.0";
dxf2csd:extract-directory(/.)

