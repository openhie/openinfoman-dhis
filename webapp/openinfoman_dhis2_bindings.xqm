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
             <h3>Upload Meta-Data Export (DXF Document)</h3>
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
		   <label for='dxf' >Meta-data Export. (Required)</label>
		   <p>DHIS2 Meta-data export (DXF 2.0) File. </p>
		   <input type='file' name='dxf'/>
		   <br/>
		   <label for='url' >URL(Required)</label>
		   <p>The URL of the source DHIS2 system. </p>

		   <input type='text' size='120' name='url'/>
		   <label for='group_codes' >Group Codes</label>
		   <p>Comma seperated list of the Group Codes used to identify a facility</p>
		   <input type='text' size='120' name='group_codes'/>
		   <br/>
		   <label for='level' >Levels</label>
		   <p>		   Levels used to identify a facility</p>

		   <input type='checkbox' name='level' value='1'/>1 		   
		   <input type='checkbox' name='level' value='2'/>2
		   <input type='checkbox' name='level' value='3'/>3
		   <input type='checkbox' name='level' value='4'/>4
		   <input type='checkbox' name='level' value='5'/>5
		   <input type='checkbox' name='level' value='6'/>6
		   <input type='checkbox' name='level' value='7'/>7
		   <input type='checkbox' name='level' value='8'/>8
		   <input type='checkbox' name='level' value='9'/>9
		   <br/>
		   <label for='oid' >OID</label>
		   <p>
		     The root OID used for publishing SVS lists of the extracted meta-data (e.g. org unit groups, org unit levels).  		     
		     If you don't have one, OpenInfoMan will make a random one of the form '2.25.$RANDOM' where $RANDOM is the decimal 
		     representation of a Version 3 UUID generated from the DHIS2 host URL.
		   </p>		   
		   <input type='text' size='120' name='oid'/>
		   <br/>
		   <br/>
		   <label for='do_hws' >Process Users</label>
		   <p>
		   Process DHIS2 users as health workers (CSD Providers).

		   In order to do so, you will need to have included Users, UserRoles and UserAuthorityGroups in your DXF2 meta-data extract
		   </p>

		   <select name='do_hws'>
		     <option value='0'>No</option>
		     <option value='1'>Yes</option>
		   </select>
		   
		   <hr/>
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



declare updating
  %rest:path("/CSD/csr/{$doc_name}/careServicesRequest/{$search_name}/adapter/dhis2/simple_upload")
  %rest:POST
  %rest:form-param("dxf", "{$dxf}")
  %rest:form-param("oid", "{$oid}")
  %rest:form-param("url", "{$url}")
  %rest:form-param("level", "{$level}")
  %rest:form-param("group_codes", "{$group_codes}")
  %rest:form-param("do_hws", "{$do_hws}")
  function page:update_doc($search_name,$doc_name,$dxf,$oid,$url,$level,$group_codes,$do_hws) 
{
  if (not(page:is_dhis($search_name)) ) then
    db:output(<restxq:redirect>{$csd_webconf:baseurl}CSD/bad</restxq:redirect>)
  else 
    let $function := csr_proc:get_updating_function_definition($csd_webconf:db,$search_name)
    let $name :=  map:keys($dxf)[1]
    let $content := parse-xml(convert:binary-to-string($dxf($name)))
    let $levels := for $l in $level return <level>{$l}</level>
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
         </csd:requestParams>
       </csd:function>
      </csd:careServicesRequest>
    return 
       (
        csr_proc:process_updating_CSR_results($csd_webconf:db, $careServicesRequest)
        ,db:output(<restxq:redirect>{$csd_webconf:baseurl}CSD</restxq:redirect>)
       )

};
