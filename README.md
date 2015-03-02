openinfoman-dhis
================

XQuery Libary for DHIS2 and DXF support using CSD

It makes use of the OpenInfoMan software https://github.com/openhie/openinfoman

Ubuntu Installation
===================
You can easily install on Ubuntu 14.04 and Ubuntu 14.10 using the following commands
<pre>
sudo add-apt-repository ppa:openhie/release
sudo apt-get update
sudo apt-get install openinfoman-dhis
</pre>



Manual Installation
===================


Assumes that you have installed BaseX and OpenInfoMan according to:
> https://github.com/openhie/openinfoman/wiki/Install-Instructions

and the OpenInfoMan CSV adapter
> https://github.com/openhie/openinfoman-csv

and the FunctX XQuery Library:
<pre>
 basex -Vc "REPO INSTALL http://files.basex.org/modules/expath/functx-1.0.xar"
</pre>

Directions
----------
<pre>
cd ~/
git clone https://github.com/openhie/openinfoman-dhis
cd ~/openinfoman-dhis/repo
basex -Vc "REPO INSTALL dxf_1_0.xqm"
basex -Vc "REPO INSTALL dxf2csd.xqm "
cd ~/basex/resources/stored_query_definitions
ln -sf ~/openinfoman-dhis/resources/stored_query_definitions/* .
cd ~/basex/resources/stored_updating_query_definitions
ln -sf ~/openinfoman-dhis/resources/stored_updating_query_definitions/* .
cd ~/basex/webapp
ln -sf ~/openinfoman-dhis/webapp/openinfoman_dhis2_bindings.xqm
cd ~/basex/resources/service_directories/
ln -s ~/openinfoman-dhis/resources/service_directories/* .
</pre>

Be sure to reload the stored functions: 
> https://github.com/openhie/openinfoman/wiki/Install-Instructions#Loading_Stored_Queries
