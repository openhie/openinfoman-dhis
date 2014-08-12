import module namespace dxf_conf = "http://dhis2.org/csd/config" at "DHIS_config.xqm";
import module namespace random = "http://basex.org/modules/random";
declare namespace pma = "http://www.phpmyadmin.net/some_doc_url/";
declare namespace csd = "urn:ihe:iti:csd:2013";


let $urn_moh := "urn:dhis.org:sierra-leone-demo:csd:organization:ImspTQPwCqd"
let $fac_urns := ("AvGz949akv4","F7u30K5OIpi","gUPhNWkSXvD","RVAkLOVWSWc","GQpxsB7tekR","cZZG5BMDLps","svCLFkT99Yx","AFi1GjbeejL","ZZmMpGIE7pD","gei3Sqw8do7","ZALwM386w0T","XfVYz6l2rzg","M721NHGtdZV","W7ekX3gi0ut","XJ6DqDkMlPv","Bift1B4gjru","gsypzntLahf","MuZJ8lprGqK","ZKL5hlVG6F6","dCvUVvKnhMe","jk1TtiBM5hz","mEUUK7MHLSF","jNb63DIHuwU","TSyzvBiovKh","Umh4HKqqFp6","DiszpKrYNg8","bvV8jXFvZ4K","ZIqREl9AlUJ","zfLTswAf6Q2","OqfQZ8hOxbm")
let $cadres := ("AHP","PHM","MD","NUR")


return 
<csd:CSD>
  <csd:organizationDirectory/>
  <csd:serviceDirectory/>
  <csd:facilityDirectory/>
  <csd:providerDirectory>
  {
    for $person in /pma_xml_export/database/*
    let $id := $person/column[@name='id']/text()
    let $urn := concat("urn:ihris.org:manage-demo:csd:provider:",$id)
    let $lm := replace($person/column[@name='last_modified']/text(),' ' , 'T')
    let $created := $lm
    let $sur := $person/column[@name='firstname']/text()
    let $fore := $person/column[@name='surname']/text()    
    let $cpos := random:integer(count($cadres)-1)+1
    let $cadre := $cadres[position() = $cpos]
    return 
      <csd:provider urn="{$urn}">        
        <csd:codedType code="{$cadre}" codingScheme="2.25.11111176868615247452370557526986886924"/>
	<csd:demographic>
	  <csd:name>
	    <csd:commonName>{$sur}, {$fore}</csd:commonName>
	    <csd:forename>{$fore}</csd:forename>
	    <csd:surname>{$sur}</csd:surname>
	  </csd:name>
	</csd:demographic>	     
	<csd:organizations>
	  <csd:organization urn="{$urn_moh}"/>
	</csd:organizations>
	<csd:facilities>
	 {
	   let $pos := random:integer(count($fac_urns)-1)+1
	   let $fac_urn := $fac_urns[position() = $pos]
	   return <csd:facility urn="urn:dhis.org:sierra-leone-demo:csd:facility:{$fac_urn}"/>
	 }
	</csd:facilities>
	<csd:record created="{$created}" updated="{$lm}" status="106-001" sourceDirectory="http://demo.ihris.org/manage"/>
      </csd:provider>
  }
  </csd:providerDirectory>
</csd:CSD>
