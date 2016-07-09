module namespace util = "https://github.com/openhie/openinfoman-dhis/util";

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
  let $zero := convert:binary-to-bytes('0')
  let $nine := convert:binary-to-bytes('9')
  let $a := convert:binary-to-bytes('A')
  let $e := convert:binary-to-bytes('E')
  let $u_hex := convert:binary-to-bytes(upper-case($hex))
  let $dec := $u_hex
    ! xs:decimal(if ( (. >= $zero and . <= $nine)) then (. - $zero) else if ( (. >= $a and . <= $e)) then (. - $a + 10) else ())
  return  fold-left($dec, 0, function($a, $b) { $a * 16 + $b }) 
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
  (: adapted from http://www.ietf.org/rfc/rfc4122.txt and https://gist.github.com/dahnielson/508447 :)
  let $bits := util:uuid_tobits(functx:chars(translate($namespace,'-','' )))
  let $s_bits := serialize($bits)
  let $hash := serialize(xs:hexBinary(hash:md5(concat($s_bits,  $name))))

  let $uuid :=
    concat(
      substring( $hash,1, 8)
      ,'-'
      ,substring( $hash,9, 4)  
      ,'-'
      ,xs:hexBinary(bin:or(bin:and(bin:hex(substring($hash, 13, 4)),bin:hex('0FFF')),bin:hex('3000')))
      ,'-'
       ,xs:hexBinary(bin:or( bin:and(bin:hex(substring( $hash,17, 4)) , bin:hex('3FFF')) , bin:hex('8000')))
      ,'-'
      ,substring( $hash,21, 12)
      )
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









