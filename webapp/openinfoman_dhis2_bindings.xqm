module namespace page = 'http://basex.org/modules/web-page';

(:Import other namespaces.  :)
import module namespace csd_webconf =  "https://github.com/openhie/openinfoman/csd_webconf";
import module namespace csr_proc = "https://github.com/openhie/openinfoman/csr_proc";
import module namespace csd_dm = "https://github.com/openhie/openinfoman/csd_dm";
import module namespace csd_mcs = "https://github.com/openhie/openinfoman/csd_mcs";
import module namespace functx = "http://www.functx.com";

declare namespace csd = "urn:ihe:iti:csd:2013";


declare function page:is_dhis($search_name) {
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $ufunction := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
  let $ext := $function//csd:extension[  @urn='urn:openhie.org:openinfoman:adapter' and @type='dhis2']
  let $uext := $ufunction//csd:extension[  @urn='urn:openhie.org:openinfoman:adapter' and @type='dhis2']
  return (count($uext) + count($ext) > 0) 
};


declare function page:get_actions($search_name) {
  let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
  let $ufunction := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
  return 
    (
    for $act in $function//csd:extension[  @urn='urn:openhie.org:openinfoman:adapter:dhis2:action']/@type
    return string($act)
    ,for $act in $ufunction//csd:extension[  @urn='urn:openhie.org:openinfoman:adapter:dhis2:action']/@type
    return string($act)
  )
};



declare
  %rest:path("/CSD/csr/{$doc_name}/careServicesRequest/{$search_name}/adapter/dhis2")
  %output:method("xhtml")
  function page:show_endpoints($search_name,$doc_name) 
{  
    if (not(page:is_dhis($search_name)) ) 
      then ('Not a DHIS2 Compatible stored function'    )
    else 
      let $actions := page:get_actions($search_name)
      let $contents := 
      <div>
        <h2>DHIS Operations on {$doc_name}</h2>
        { 
          if ($actions = 'createDXF')  
	  then
	   <span>
             <h3>Generate DHIS2 DXF Document</h3>
	     {
	       let $url := concat($csd_webconf:baseurl, "CSD/csr/" , $doc_name , "/careServicesRequest/",$search_name, "/adapter/dhis2/createDXF")
	       return <a href="{$url}">Get DXF</a>
	     }
	   </span>
	  else ()
	}
        { 
          if ($actions = 'upload')  
	  then
	   <span>
             <h3>Upload DXF Document</h3>
	     {
	       let $function := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
	       let $oid := string($function/csd:extension[@urn='urn:openhie.org:openinfoman:adapter:dhis2:action:uploadDXF:oid']/@type)		 
	       let $url := concat($csd_webconf:baseurl, "CSD/csr/" , $doc_name , "/careServicesRequest/",$search_name, "/adapter/dhis2/upload")
	       return 
	         <form action="{$url}" method="POST" enctype="multipart/form-data">
		   <label for='dxf' >DHIS2 Metadata DXF 2.0 File</label>
		   <input type='file' name='dxf'/>
		   <br/>
		   <label for='oid' >Root OID for SVS list ID</label>
		   <input type='text' size='60' value="{$oid}" name='oid'/>
		   <br/>
		   <input type='submit' value='Upload'/>
		 </form>
	     }
	   </span>
	  else ()
	}
        { 
          if ($actions = 'simple_upload')  
	  then
	   <span>
             <h2>Upload Meta-Data Export (DXF Document)</h2>
	     <p>
	     This extracts all organisation units matching the given facility conditions as a CSD facility entity.  
	     It also extracts all organisation units a CSD organization entity.  
	     In the case that a CSD facility entity is created, it will have as an organizational association to it's corresponding organization entity.
	     These two entities will have distinct entity IDs (UUIDs)
	     </p>
	     {
	       let $function := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
	       let $oid := string($function/csd:extension[@urn='urn:openhie.org:openinfoman:adapter:dhis2:action:uploadDXF:oid']/@type)		 
	       let $url := concat($csd_webconf:baseurl, "CSD/csr/" , $doc_name , "/careServicesRequest/",$search_name, "/adapter/dhis2/simple_upload")
	       return 
	         <form action="{$url}" method="POST" enctype="multipart/form-data">
		   <h3>Data Source</h3>
		   <label for='dxf' >Meta-data Export. (Required)</label>
		   <p>DHIS2 Meta-data export (DXF 2.0) File. </p>
		   <input type='file' name='dxf'/>
		   <br/>

		   <label for='url' >URL(Required)</label>
		   <p>The URL of the source DHIS2 system. </p>

		   <input type='text' size='120' name='url'/>

		   <br/>
		   <h3>Provider Directory</h3>
		   <label for='do_hws' >Process Users</label>
		   <p>
		   Process DHIS2 users as health workers (CSD Providers).

		   In order to do so, you will need to have included Users, UserRoles and UserAuthorityGroups in your DXF2 meta-data extract
		   </p>

		   <select name='do_hws'>
		     <option value='0'>No</option>
		     <option value='1'>Yes</option>
		   </select>
		   <br/>
		   <h3>Service Directory</h3>
		   <label for='do_srvcs' >Process Data Elements</label>
		   <p>
		   Process DHIS2 Data Elements as CSD Services

		   In order to do so, you will need to have included Data Elements, Categtories and Category Combos in your DXF2 meta-data extract
		   </p>

		   <select name='do_srvcs'>
		     <option value='0'>No</option>
		     <option value='1'>Yes</option>
		   </select>
		   
		   <hr/>
		   <h3>Facility Directory</h3>
		   <label for='group_codes' >Group Codes</label>
		   <p>Comma seperated list of the Group Codes used to identify a facility</p>
		   <input type='text' size='120' name='group_codes'/>
		   <br/>
		   <label for='level' >Levels</label>
		   <p>		   Levels used to identify a facility</p>
		     <input type='checkbox' name='level1' value='1'/>1 		   
		     <input type='checkbox' name='level2' value='2'/>2
		     <input type='checkbox' name='level3' value='3'/>3
		     <input type='checkbox' name='level4' value='4'/>4
		     <input type='checkbox' name='level5' value='5'/>5
		     <input type='checkbox' name='level6' value='6'/>6
		     <input type='checkbox' name='level7' value='7'/>7
		     <input type='checkbox' name='level8' value='8'/>8
		     <input type='checkbox' name='level9' value='9'/>9 
		   <br/>
		   <h3>HIE Configuration</h3>
		   <label for='oid' >OID</label>
		   <p>
		     The root OID used for publishing SVS lists of the extracted meta-data (e.g. org unit groups, org unit levels).  		     
		     If you don't have one, OpenInfoMan will make a random one of the form '2.25.$RANDOM' where $RANDOM is the decimal 
		     representation of a Version 3 UUID generated from the DHIS2 host URL.
		   </p>		   
		   <input type='text' size='120' name='oid'/>
		   <br/>

		   <span class='pull-right'>
		     <input type='submit' value='Upload'/>
		   </span>
		 </form>
	     }
	   </span>
	  else ()
	}
      </div>
      return csd_webconf:wrapper($contents)
};


 
declare
  %rest:path("/CSD/csr/{$doc_name}/careServicesRequest/{$search_name}/adapter/dhis2/createDXF")
  function page:execute2($search_name,$doc_name) 
{
  if (not(page:is_dhis($search_name)) ) 
    then ('Not a DHIS2 Compatible stored function'    )
  else 
    let $doc :=  csd_dm:open_document($csd_webconf:db,$doc_name)
    let $function := csr_proc:get_function_definition($csd_webconf:db,$search_name)
    let $assName := "dhis.org:orgid"
    let $requestParams := 
      <csd:requestParams function="{$search_name}" resource="{$doc_name}" base_url="{$csd_webconf:baseurl}">
        <assigningAuthorityName>{$assName}</assigningAuthorityName>
      </csd:requestParams>

    return csr_proc:process_CSR_stored_results($csd_webconf:db, $doc,$requestParams)
};

declare updating
  %rest:path("/CSD/csr/{$doc_name}/careServicesRequest/{$search_name}/adapter/dhis2/upload")
  %rest:POST
  %rest:form-param("dxf", "{$dxf}")
  %rest:form-param("oid", "{$oid}",'')
  function page:update_doc($search_name,$doc_name,$dxf,$oid) 
{
  if (not(page:is_dhis($search_name)) ) then
    db:output(<restxq:redirect>{$csd_webconf:baseurl}CSD/bad</restxq:redirect>)
  else 
    let $function := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
    let $d_oid := string($function/csd:extension[@urn='urn:openhie.org:openinfoman:adapter:dhis2:action:uploadDXF:oid']/@type)
    
    let $s_oid := if ($oid = '') then $d_oid else $oid

    let $name :=  map:keys($dxf)[1]
    let $content := parse-xml(convert:binary-to-string($dxf($name)))

    let $careServicesRequest := 
      <csd:careServicesRequest>
       <csd:function urn="{$search_name}" resource="{$doc_name}" base_url="{$csd_webconf:baseurl}">
         <csd:requestParams >
           <dxf>{$content}</dxf>
           <oid>{$s_oid}</oid>
         </csd:requestParams>
       </csd:function>
      </csd:careServicesRequest>
    return 
       (
        csr_proc:process_updating_CSR_results($csd_webconf:db, $careServicesRequest)
        ,db:output(<restxq:redirect>{$csd_webconf:baseurl}CSD</restxq:redirect>)
       )

};


declare
  %rest:path("/CSD/csr/{$doc_name}/careServicesRequest/{$search_name}/adapter/dhis2/simple_upload2")
  %rest:consumes('multipart/*')
  %rest:POST("{$data}")
  function page:update_doc2($search_name,$doc_name,$data as item()*) {
    <pre>{for $d in $data return <d>{$d}</d>}</pre>
};

declare updating
  %rest:path("/CSD/csr/{$doc_name}/careServicesRequest/{$search_name}/adapter/dhis2/simple_upload")
  %rest:form-param("dxf", "{$dxf}")
  %rest:form-param("oid", "{$oid}")
  %rest:form-param("url", "{$url}")
  %rest:form-param("level1", "{$level1}")
  %rest:form-param("level2", "{$level2}")
  %rest:form-param("level3", "{$level3}")
  %rest:form-param("level4", "{$level4}")
  %rest:form-param("level5", "{$level5}")
  %rest:form-param("level6", "{$level6}")
  %rest:form-param("level7", "{$level7}")
  %rest:form-param("level8", "{$level8}")
  %rest:form-param("level9", "{$level9}")
  %rest:form-param("group_codes", "{$group_codes}")
  %rest:form-param("do_hws", "{$do_hws}")
  %rest:form-param("do_srvcs", "{$do_srvcs}")
  function page:update_doc($search_name,$doc_name,$dxf,$oid,$url,$group_codes,$do_hws,$do_srvcs,
                           $level1,$level2,$level3,$level4,$level5,$level6,$level7,$level8,$level9 (:ugly hack b/c basex is not behaving :)
		       )
{
  if (not(page:is_dhis($search_name)) ) then
    db:output(<restxq:redirect>{$csd_webconf:baseurl}CSD/bad</restxq:redirect>)
  else 
    let $function := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
    let $name :=  map:keys($dxf)[1]
    let $content := parse-xml(convert:binary-to-string($dxf($name)))
    let $levels :=
       (
	 if ($level1) then (<level>1</level>) else (),
	 if ($level2) then (<level>2</level>) else (),
	 if ($level3) then (<level>3</level>) else (),
	 if ($level4) then (<level>4</level>) else (),
	 if ($level5) then (<level>5</level>) else (),
	 if ($level6) then (<level>6</level>) else (),
	 if ($level7) then (<level>7</level>) else (),
	 if ($level8) then (<level>8</level>) else (),
	 if ($level9) then (<level>9</level>) else ()
       )
    let $group_codes_exploded := for $g in tokenize($group_codes,',') return <group_code>{$g}</group_code>
    let $careServicesRequest := 
      <csd:careServicesRequest>
       <csd:function urn="{$search_name}" resource="{$doc_name}" base_url="{$csd_webconf:baseurl}">
         <csd:requestParams >
           <dxf>{$content}</dxf>
	   <groupCodes>{$group_codes_exploded}</groupCodes>
	   <levels>{$levels}</levels>
	   <URL>{$url}</URL>
	   <OID>{$oid}</OID>
	   <usersAreHealthWorkers>{if ($do_hws = '1') then '1' else '0'}</usersAreHealthWorkers>
	   <dataelementsAreServices>{if ($do_srvcs = '1') then '1' else '0'}</dataelementsAreServices>

         </csd:requestParams>
       </csd:function>
      </csd:careServicesRequest>
    return 
       (
        csr_proc:process_updating_CSR_results($csd_webconf:db, $careServicesRequest) 
(:        ,db:output(<restxq:redirect>{$csd_webconf:baseurl}CSD</restxq:redirect>)  :)
       )

};
