module namespace util = "https://github.com/openhie/openinfoman-dhis/util";
declare namespace UUID = "java.util.UUID";
declare namespace dxf = "http://dhis2.org/schema/dxf/2.0";
declare namespace csd = "urn:ihe:iti:csd:2013";
declare namespace gml = "http://www.opengis.net/gml";
import module namespace functx = "http://www.functx.com";

declare variable $util:namespace_uuid := "10df44d2-55f4-11e4-af21-705681a860b7";

declare function util:uuid_tobits($tokens) {
  if (count($tokens) > 1)
  then  ( 
          bin:hex(concat($tokens[1],$tokens[2])),
          util:uuid_tobits(subsequence($tokens,3))
        )
  else $tokens
};


declare function util:hexdec($hex) {
  let $zero := convert:binary-to-bytes(convert:string-to-hex('0'))
  let $nine := convert:binary-to-bytes(convert:string-to-hex('9'))
  let $a := convert:binary-to-bytes(convert:string-to-hex('A'))
  let $e := convert:binary-to-bytes(convert:string-to-hex('E'))
  let $uuid := xs:hexBinary(upper-case(translate($hex,'-','')))
  let $bytes := convert:binary-to-bytes($uuid) !
    xs:decimal(if ( (. >= $zero and . <= $nine)) then (.  - $zero) else if ( (. >= $a and . <= $e)) then (. - $a + 10) else ())
  return  fold-left($bytes, 0, function($a, $b) { $a * 16 + $b }) 

};

declare function util:get_parent_orgs($all_orgs,$org) {
  let $porg_id := $org/csd:parent/@entityID
  let $porg :=
    if (functx:all-whitespace($porg_id)) 
    then ()
    else $all_orgs[@entityID = $porg_id]
  return 
    if (not(exists($porg)))
    then ()
    else (util:get_parent_orgs($all_orgs,$porg),$porg)
};

declare function util:get_child_orgs($orgs,$org) {
  let $org_id := $org/@entityID     
  let $c_orgs := 
    if (functx:all-whitespace($org_id))
    then ()
    else $orgs[./csd:parent[@entityID = $org_id]]	
  return 
    for $c_org in $c_orgs
    return ($c_org,util:get_child_orgs($orgs,$c_org))
	      

};


declare function util:uuid_generate($name,$namespace) {
  let $ns_bits := util:uuid_tobits(functx:chars(translate($namespace,'-','' )))
  let $n_bytes := convert:string-to-base64($name) 
  let $uuid := UUID:nameUUIDFromBytes(  bin:join(($ns_bits, $n_bytes)))
  return lower-case($uuid)
};



declare function util:fixup_date($date) {
  let $d := string($date)
  let $i := functx:index-of-match-first($d,'[+\-][\d:]+$')
  return
    if ($i)
    then
       let $tz := substring($d,$i)
       return  concat (
         substring($d,1,$i  - 1)
         ,
         if (matches($tz,'[+\-]\d{2}:\d{2}'))
         then $tz
         else ()
         )
    else $d
};


declare  function util:get_geocode($orgUnit) {
  let $ft := $orgUnit/dxf:featureType/text()
  let $coord := $orgUnit/dxf:coordinates/text()
  let $lat := substring-after(substring-before($coord,','),'[')
  let $long := substring-after(substring-before($coord,']'),',')
    
  return 
    if ($ft = 'POINT' and not(functx:all-whitespace($lat)) and not(functx:all-whitespace($long) ))
    then
      <csd:geocode>
        <csd:latitude>{$lat}</csd:latitude>
        <csd:longitude>{$long}</csd:longitude>
      </csd:geocode>
    else ()
};

declare  function util:get_shape($orgUnit) {
  let $ft := $orgUnit/dxf:featureType/text()
  let $coords := $orgUnit/dxf:coordinates/text()
  return 
    if ( $ft = 'MULTI_POLYGON' )
    then 
      <csd:extension urn="urn:http://www.opengis.net/gml" type="MultiPolygon">
        <gml:MultiPolygon srsName="EPSG:4326">
          <gml:polygonMember>	
	    {
	      for $poly_coord in  tokenize($coords,'\]\],\[\[')
	      return 

	        <gml:Polygon >
		  <gml:outerBoundaryIs>
		    <gml:LinearRing>
		      <gml:coordinates>
		        {
			  let $coords := 
			    for $c in  tokenize($poly_coord,'\],\[')
			    return functx:trim(translate($c,'[]',''))
			  return string-join($coords,' ')
			}
		      </gml:coordinates>
		    </gml:LinearRing>
		  </gml:outerBoundaryIs>
      		</gml:Polygon>
	    }
	  </gml:polygonMember>
	</gml:MultiPolygon>
      </csd:extension>
    else  if ($ft = 'POLYGON') 
    then
      <csd:extension urn="urn:http://www.opengis.net/gml" type="Polygon">
	<gml:Polygon >
	  <gml:outerBoundaryIs>
	    <gml:LinearRing>
	      <gml:coordinates>
		{
		  let $coords := 
		    for $c in  tokenize($coords,'\],\[')
		    return functx:trim(translate($c,'[]',''))
		  return string-join($coords,' ')
		}
	      </gml:coordinates>
	    </gml:LinearRing>
	  </gml:outerBoundaryIs>
      	</gml:Polygon>
      </csd:extension>
    else ()

};









