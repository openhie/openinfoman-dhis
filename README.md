openinfoman-dhis
================

XQuery Libary for DHIS2 and DXF support using CSD

Prerequisites
=============

Assumes that you have installed BaseX and OpenInfoMan according to:
> https://github.com/openhie/openinfoman/wiki/Install-Instructions

and the OpenInfoMan CSV adapter
> https://github.com/openhie/openinfoman-csv

and the FunctX XQuery Library:
<pre>
 basex -Vc "REPO INSTALL http://files.basex.org/modules/expath/functx-1.0.xar"
</pre>

Directions
==========
<pre>
cd ~/
git clone https://github.com/openhie/openinfoman-dhis
cd ~/openinfoman-dhis/repo
basex -Vc "REPO INSTALL dxf_1_0.xqm"
cd ~/basex/resources/stored_query_definitions
ln -sf ~/openinfoman-dhis/resources/stored_query_definitions/* .
</pre>

Be sure to reload the stored functions: 
> https://github.com/openhie/openinfoman/wiki/Install-Instructions#Loading_Stored_Queries
