<?php

  //curl -vv -X POST -H 'content-type: text/xml'  --data-binary @post.xml  http://54.237.247.69

$host = 'http://52.90.211.227:8984';
$host = 'http://54.237.247.69:8984';
$document  = 'DATIM-Global.2.23.2016';
$start_org = 'urn:uuid:a0c7c9cb-cdc4-4d24-b644-04dfcd45f9ea';



//no need to edit from here
$org_queue = array($start_org);
$csrurl = $host . '/CSD/csr/DATIM-Global.2.23.2016/careServicesRequest/urn:dhis.org:transform_to_dxf:v2.19';
$ch = curl_init();
$curl_opts = array(
    CURLOPT_POST => 1,
    CURLOPT_HTTPHEADER => Array("Content-Type: text/xml"),
    CURLOPT_URL => $csrurl,
    CURLOPT_FAILONERROR => 1,
    CURLOPT_RETURNTRANSFER => 1,
    CURLOPT_TIMEOUT => false
    );
curl_setopt_array($ch, $curl_opts);
$qry = '/dxf:metaData/dxf:organisationUnits/dxf:organisationUnit/dxf:attributeValues/dxf:attributeValue/dxf:attribute[@name="entityID"]/../dxf:value';
$time_start = microtime(true);
$seen = array();
$tot = 0;
while (($qs = count($org_queue)) > 0) {
    $tot++;
    echo "Queue Size: $qs\n";
    echo "\tProcessed: $tot\n";
    $duration = (microtime(true) - $time_start);
    echo "\tTime (sec): " . $duration . "\n";
    echo "\tTime (min): " . ($duration/60) . "\n";
    $org = array_pop($org_queue);
    $seen[] = $org;
    $request = "
<csd:requestParams xmlns:csd='urn:ihe:iti:csd:2013'>
  <csd:organization entityID='$org'/>
  <processUsers value='0'/>
  <onlyDirectChildren value='1'/>
  <preserveUUIDs value='0'/>
  <zip value='0'/>
</csd:requestParams>";

    curl_setopt($ch, CURLOPT_POSTFIELDS, $request); 
    $r_time_start = microtime(true);
    $response = curl_exec($ch);
    $duration = (microtime(true) - $r_time_start);
    echo "\tRequest: $duration\n";
    if ($e = curl_error($ch)) {
        echo('Error:' . $e . "\n");
        continue;
    }
    $doc = new DOMDocument();
    if (! ($doc->loadXML($response))) {
        echo "Invalid: $response";
        continue;
    }
    $xpath = new DOMXpath($doc);
    $xpath->registerNamespace('dxf','http://dhis2.org/schema/dxf/2.0');

    $found =false;
    foreach ($xpath->query($qry) as $node) {
        $urn = 'urn:uuid:' . $node->textContent;
        if ($urn == $org) {
            $found = true;
            $orgNode = $node->parentNode->parentNode->parentNode;
            echo "\tMatched " . $orgNode->getAttribute('name') . " at " . $orgNode->getAttribute('level') . "\n";
        }
        if (!$found) {
            continue;
        }
        if (!in_array($urn,$seen)) {
            echo "\tAdding $urn\n";
            $org_queue[] = $urn;
        }
    }
}
echo "Done\n";
$duration = (microtime(true) - $time_start);
echo "\tTime (sec): " . $duration . "\n";
echo "\tTime (min): " . ($duration/60) . "\n";