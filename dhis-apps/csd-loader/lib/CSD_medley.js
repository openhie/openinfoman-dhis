var CSDLoader = function(form) {
    this.form = form;
    this.status = this.form.find( ".csdstatus" );
    this.BaseURL = window.location.href.substring(0, window.location.href.indexOf('/api/apps/csd-loader'));
    this.Log('BaseURL=' + this.BaseURL);
    this.BaseILRURL = this.BaseURL.substring(0,this.BaseURL.lastIndexOf('/'))+ '/ILR/CSD';   
    this.Log('Base ILR URL=' + this.BaseILRURL);
    this.xmlSerializer = new XMLSerializer();
    this.BindActions();
};

CSDLoader.prototype.Log = function(text) {
    console.log(text);
};

CSDLoader.prototype.UpdateStatus = function(text) {
    this.Log(text);
    if (!this.status) {
	return;
    }
    this.status.empty();
    this.status.text(text);    
};

CSDLoader.prototype.SetStatusAsLoading = function(isloading) {
    if (!this.status) {
	return;
    }
    if (isloading) {
	this.status.css('background-size', '16px 11px');
	this.status.css('background-repeat', 'no-repeat');
	this.status.css('background-image', 'url(../images/ajax-loader-bar.gif)');
	this.status.css('background-position', 'right center');
    } else {
	this.status.css('background-image', '');
    }
};

CSDLoader.prototype.Alert = function(text) {
    this.UpdateStatus(text);
    alert(text);
};

CSDLoader.prototype.GetServerTime = function () {
    this.Log('getting time from ' + this.BaseURL + '/api/metadata');
    var time = false;
    var options = {
	url: this.BaseURL + '/api/metadata',
	method: 'GET',
	type: 'GET',
	dataType: "xml",
	async: false,
	context: this,
	cache: false,
	data :
 	  {
	   assumeTrue:false
	  },

	error: $.proxy(function(xml) {
	    this.Log('could not fetch time');
	},this),
	success: $.proxy(function(xml) {
	    //extract time from	<metaData xmlns="http://dhis2.org/schema/dxf/2.0" created="2015-09-25T12:25:52.636+0000">
	    time = $(xml).find('metaData').attr('created');
	},this)
    };
    $.ajax(options);
    this.Log('metadata time = ' + time);
    return time;

};


CSDLoader.prototype.GetKeys = function() {
    this.Log('getting keys');
    var keys  = [];
    var options = {
	url: this.BaseURL + '/api/dataStore/CSD-Loader',
	method: 'GET',
	type: 'GET',
	dataType: "json",
	async: false,
	context: this,
	cache: false,
	error: $.proxy(function() {
	    this.Log('could not fetch last modified time');
	},this),
	success: $.proxy(function(json) {
	    //extract time from	<metaData xmlns="http://dhis2.org/schema/dxf/2.0" created="2015-09-25T12:25:52.636+0000">
	    keys = json;
	},this)
    };
    $.ajax(options);
    this.Log("Got Keys:" + keys.join());
    return keys;

};


CSDLoader.prototype.SetupGroups = function(elem) {
    this.Log('getting groups');
    var options = {
	url: this.BaseURL + '/api/organisationUnitGroups',
	method: 'GET',
	type: 'GET',
	dataType: "json",
	data: {'paged':'false'},
	context: this,
	cache: false,
	error: $.proxy(function() {
	    this.Log('could not fetch groups');
	},this),
	success: $.proxy(function(json) {
	    //extract time from	<metaData xmlns="http://dhis2.org/schema/dxf/2.0" created="2015-09-25T12:25:52.636+0000">
	    this.Log("Got groups " + JSON.stringify(json));
	    $.each(json['organisationUnitGroups'], $.proxy(function(i,group) {
		if (group['code']) {
		    var html = '<p><input class="groupcode" type="checkbox" value="' + group['code'] + '"/>' + group['name'] + '</p>';
		    this.Log('Adding ' + html);
		    elem.append(html);
		}
	    },this));
	},this)
    };
    $.ajax(options);
    return true;
};

CSDLoader.prototype.SetLastModified = function(time) {
    var method =  ($.inArray('LastExported',this.GetKeys()) >= 0)  ?  'PUT' : 'POST';
    this.Log('setting export to ' + time + ' using ' + method);
    var options = {
	url: this.BaseURL + '/api/dataStore/CSD-Loader/LastExported',
	method: method,
	contentType: 'application/json',
	type: method,
	dataType: "text",
	data : JSON.stringify({value : time}),
	context: this,
	cache: false,
	error: $.proxy(function() {
	    this.Log('could not set last modified time');
	},this),
	success: $.proxy(function(json) {
	    this.Log('set last modified time to ' + time);
	},this)
    };
    $.ajax(options);
    return time;
};


CSDLoader.prototype.FetchLastModified = function() {
    this.Log('getting last modfified');
    var time = false;
    var options = {
	url: this.BaseURL + '/api/dataStore/CSD-Loader/LastExported',
	method: 'GET',
	type: 'GET',
	dataType: "json",
	async: false,
	context: this,
	cache: false,
	error: $.proxy(function() {
	    this.Log('could not fetch last modified time');
	},this),
	success: $.proxy(function(json) {
	    //extract time from	<metaData xmlns="http://dhis2.org/schema/dxf/2.0" created="2015-09-25T12:25:52.636+0000">
	    time = json['value'];
	},this)
    };
    $.ajax(options);
    this.Log('last modified time = ' + time);
    return time;
};

CSDLoader.prototype.BindActions = function() {
    if (!this.form) {
	return;
    }

    this.form.click(  $.proxy(function(event) {
	//save the orgin of every click within this form so we can recover submission button
	$(this).data('clicked',$(event.target));
    },this));

    var lm  = this.form.find('input[name=lastmodified]');
    var groupElem = this.form.find('.groupcodes');
    if (groupElem) {
	this.SetupGroups(groupElem);
    }

    if (lm) {
	var lmt = this.FetchLastModified();
	this.Log('Last Exported ' + lmt);
	var options = {
	    format:'c',
	    startDate:'+2016/01/01'
	    };
	if (lmt) {
	    options['value']=new Date(lmt);
	}
	this.Log(JSON.stringify(options));
	lm.datetimepicker(options);
    }
    var alldata = this.form.find('select[name=alldata]');
    var lmc = this.form.find('.lastmodifiedcontainer');    
    if (alldata && lmc) {
	alldata.val('1');
	lmc.hide();
	alldata.change(function() {
	    if (alldata.val() == 0) {
		lmc.show();
	    } else{
		lmc.hide();
	    }
	});
    }

    
    this.form.submit( $.proxy(function( event ) {
	event.preventDefault();
	var action = $(this).data('clicked').attr('value');
	switch (action) {
	case 'Select':
	    this.UpdateSelection();
	    break;
	case 'Import':
	    this.ImportSelected();
	    break;
	case 'Export':
	    this.Export();
	    break;
	default:
	    this.Alert('Unrecognzied Action: ' + action);		
	}
		
    },this));


    this.form.find('select[name=docs]').change( $.proxy( function() {
        this.UpdateSelection();
    },this));

    this.form.find('select[name=org]').change( $.proxy( function() {
	this.UpdateSelection();
    },this));
};



CSDLoader.prototype.ping = function() {
    var url= this.BaseURL + '/api/configuration/systemId';
    var ping =  function() {
	$.ajax({
	    url: url,
	    error: function() {
		console.log('error ping');
		setTimeout( ping,60000);
	    },
	    success: function() {
		console.log('success ping');
		setTimeout( ping,60000);
	    }
	});	
    };
    ping();
};

CSDLoader.prototype.LoadDocs = function() {
    
    var docs = this.form.find('select[name=docs]');
    if (!docs) {
	return;
    }
    this.Log('getting docs');
    $.ajax({
	url: this.BaseILRURL + '/documents.json',
	contentType: 'application/json',
	dataType: "text",
	cache: false,
	context: this,
	error: $.proxy(function() {
	    this.Log('error on fetch');
	    this.UpdateStatus('Could not load the CSD documents.  You need to ensure the InterLinked Registry is running at ' + this.BaseILRURL);
	},this),
	success: $.proxy(function(json) {
	    this.Log('got documents' + json);
	    docs.empty();
	    docs.append("<option vaue=''>Select A Document</option>");
	    var doclist = $.parseJSON(json);
	    this.Log(doclist[0]);
	    $.each(doclist,
	           function(key,value) {
		       var id = key;
		       var name = key;
		       docs.append("<option value='" + id + "'>" + name + "</option>");
		   });
	    this.Log('updated docs dropdown');
	    this.UpdateSelection();
	},this)
    });
};
	  
CSDLoader.prototype.UpdateSelection = function() { 
    var doc = this.form.find('select[name=docs] option:selected').val();
    var url  = this.BaseILRURL + '/csr/' + doc + '/careServicesRequest/urn:ihe:iti:csd:2014:stored-function:organization-search';
    var selected = this.form.find('select[name=org] option:selected');
    var parentID = selected.val();
    var parentName = selected.text();
    var msg ="<csd:requestParams xmlns:csd='urn:ihe:iti:csd:2013'><csd:parent entityID='" + parentID + "'/></csd:requestParams>";
    this.Log('sending to ' + url + "\n" + msg);
    this.Log(url);
    $.ajax({
	method:'POST',
	type: 'POST',
	url:url,
	data:msg,
	contentType: 'text/xml',
	dataType: "xml",
	cache: false,
	context: this,
	error: $.proxy(function() {
	    this.Log('error on fetch');
	    this.Alert('Could not load the organisation units');
	},this),
	
	success: $.proxy(function(xml) {
	    this.Log('done');
            var select = this.form.find('[name=org]');
	    select.empty();
	    if (parentID) {
  	          select.append("<option value='" + parentID +"'>" + parentName + "</option>");	    
	    }
	    select.append("<option value=''></option>");
	    this.Log("Received\n" +  this.xmlSerializer.serializeToString(xml));
	    var logger = this.Log;
	    $(xml).find("csd\\:organization,organization").each(
	        function() {
		    logger(this);
		    var id = $(this).attr('entityID');
		    var name = $(this).find('csd\\:primaryName,primaryName').text();
		    logger('Adding: ' + id + ' ' + name);
		    select.append("<option value='" + id + "'>" + name + "</option>");
		});
	    this.Log('updated dropdown');
	    return true;
	},this)
    });
   
};


CSDLoader.prototype.Export = function() {
    this.UpdateStatus('Beginning Export');
    var doUsers = this.form.find('select[name=users] option:selected').val() == '1' ? true : false;
    var groupCodes = '';
    $.each(this.form.find('input.groupcode:checked'), function(i,e) {
	groupCodes += "<groupCode>" + $(e).val() + "</groupCode>";
    });
    this.Log('GC=' + groupCodes);

    var levels = '';
    var dhis2time = this.GetServerTime();
    this.form.find('input.level:checked').each( $.proxy(
      function(key,value) {
	   levels += "<level>" + value.value + "</level>";
      },this));
    var lmt = this.form.find('input[name=lastmodified]').val();
    var doall = this.form.find('select[name=alldata] option:selected').val();
    var data = 	  {
	   assumeTrue:false,
	   categoryOptions:true,
	   optionSets:true,
	   dataElementGroupSets:true,
	   userRoles: doUsers,
	   organisationUnits:true,
	   userGroups: doUsers,
	   organisationUnitGroups:true,
	   organisationUnitLevels:true,
	   categoryOptionGroupSets:true,
	   categoryCombos:true,
	   organisationUnitGroupSets:true,
	   options:true,
	   categoryOptionCombos:true,
	   dataSets:true,
	   dataElementGroups:true,
	   dataElements:true,
	   categoryOptionGroups:true,
	   categories:true,
	   users:doUsers	  	   
	  };
    console.log('Do all ' + doall);
    if (lmt && doall != 1) {
	data['lastUpdated'] = $.datepicker.formatDate('yy-mm-dd', new Date(lmt));
	
    }

    this.Log('Sending to DHIS2: ' + JSON.stringify(data));

    this.SetStatusAsLoading(true);
    $.ajax({
	url: this.BaseURL + '/api/metadata',
	method: 'GET',
	type: 'GET',
	context: this,
	data : data,
	dataType: 'text',
	error: $.proxy(function(xhr,status,error) {	    
	    this.Alert('Could not upload the metadata');
	    this.SetStatusAsLoading(false);
	    this.Log( status + "/" + error);
	    this.UpdateStatus('Data Export From DHIS2 Failed');
	    },this),
	success: $.proxy(function(xml) {
	    this.Log("Received\n" +   xml);
	    xml  = xml.replace(/\<(\?xml|(\!DOCTYPE[^\>\[]+(\[[^\]]+)?))+[^>]+\>/g, '');
	    this.UpdateStatus('Data Import To ILR Initiating');
	    this.SetStatusAsLoading(true);
	    var doc = this.form.find('select[name=docs] option:selected').val();
	    var url  = this.BaseILRURL + '/csr/' + doc + '/careServicesRequest/update/urn:dhis.org:extract_from_dxf:v2.19';
    
	    var msg =
		  "<csd:requestParams xmlns:csd='urn:ihe:iti:csd:2013'>\n"
	    	+ "   <dxf>\n" + xml +"\n</dxf>\n"
		+ "   <groupCodes>" + groupCodes + "</groupCodes>\n"
		+ "   <levels>" + levels + "</levels>\n"
		+ "   <URL>"+ this.BaseURL +"</URL>\n"
		+ "   <oid/>\n"
		+ "   <usersAreHealthWorkers>" + (doUsers ? '1' : '0') + "</usersAreHealthWorkers>\n"
		+ "   <dataelementsAreServices/>\n"
		+ " </csd:requestParams>\n";
	    this.UpdateStatus('Publishing Data To ILR');
	    this.Log("Sending to " + url + "\n" + msg);
	    $.ajax({
		method:'POST',
		type: 'POST',
		url:url,
		data:msg,
		contentType: 'text/xml',
		dataType: "xml",
		context: this,
		cache: false,
		error: $.proxy(function(xhr,status,error) {
		    this.Alert('Failed To Send Data To ILR');
		    this.Log( + status + "/" + error);
		    this.SetStatusAsLoading(false);
		},this),
		success: $.proxy(function(xml) {
		    this.UpdateStatus('Sent Data For Import To ILR');
		    this.Log('Setting last modified time to ' + dhis2time);
		    this.SetLastModified(dhis2time);		    
		    this.SetStatusAsLoading(false);
		},this)
	    });
 	},this)
    });

};


CSDLoader.prototype.PollImportStatus = function(that) {
    var url= that.BaseURL + '/api/system/tasks/METADATA_IMPORT';
    that.Log('polling import at '  + url);
    SetStatusAsLoading = $.proxy(that.SetStatusAsLoading,that);
    UpdateStatus = $.proxy(that.UpdateStatus,that);
    var pingImport =  function() {
	$.ajax({
	    url: url,
	    contentType: "application/json",
	    error: function(e) {
		that.Log('Error' + JSON.stringify(e));
		console.log('error pingImport');
		UpdateStatus("Could not get DHIS2 Import Status");
		SetStatusAsLoading(false);
	    },
	    success: function(m) {
		console.log('success pingImport');
		UpdateStatus("DHIS2 Import Status:" + JSON.stringify(m));
		setTimeout( pingImport,2000);
	    }
	});	
    };
    pingImport();
};

CSDLoader.prototype.ImportSelected = function() {
    this.UpdateStatus('Beginning Data Import');
    var doc = this.form.find('select[name=docs] option:selected').val();
    var url  = this.BaseILRURL + '/csr/' + doc + '/careServicesRequest/urn:dhis.org:transform_to_dxf:v2.19';
    var selected = this.form.find('select[name=org] option:selected');
    var parentID = selected.val();
    var doUsers = this.form.find('select[name=users] option:selected').val() == '1' ? true : false;
    var doUUIDs = this.form.find('select[name=uuids] option:selected').val() == '1' ? true : false;
    var onlyChildren = this.form.find('select[name=children] option:selected').val() == '1' ? true : false;
    var msg =
      "<csd:requestParams xmlns:csd='urn:ihe:iti:csd:2013'>\n"
      +" <csd:organization entityID='" + parentID + "'/>\n"
      +" <processUsers value='" + (doUsers ? '1' : '0') + "'/>\n"
      +" <preserveUUIDs value='" + (doUUIDs ? '1' : '0') + "'/>\n"
      +" <onlyDirectChildren value='" + (onlyChildren ? '1' : '0') + "'/>\n"
      +"</csd:requestParams>";
    this.UpdateStatus('Requesting Data From ILR');
    this.Log('SENDING to ' + url + "\n" + msg);

    var xhr = new XMLHttpRequest();
    xhr.open('POST', url, true);
    xhr.responseType = 'blob';
    xhr.setRequestHeader("Content-type", "text/xml");
    this.SetStatusAsLoading(true);
    xhr.onerror = $.proxy(function() {
	this.UpdateStatus('Retrieving Data For Import To DHIS2 Failed');
	this.SetStatusAsLoading(false);
    },this);
    that = this;
    xhr.onload = function(e) {
	that.UpdateStatus('loaded' + this.status + '/' + this.readyState);
	if (this.status == 200) {
	    var blob = new Blob([this.response],{type:'application/zip'});
	    console.log(blob);
	    that.UpdateStatus('Sending Data For Import To DHIS');
	    console.log(that.BaseURL);
	    $.ajax({
	        url: that.BaseURL + '/api/metadata.xml.zip',
	        method: 'POST',
	        type: 'POST',
		context: that,
		data:  blob,
		contentType: "application/xml",
		processData: false,
		error: function(e) {
		    that.Log('Error' + JSON.stringify(e));
		    that.Alert('Could not upload the metadata');
		    that.UpdateStatus('Data Import On DHIS2 Failed');
		    that.SetStatusAsLoading(false);
		    that.PollImportStatus(that);
		},
		success: function(xmlResponse) {
		    that.Log("Received\n" +   xmlResponse);		    
		    that.UpdateStatus('Data Import On DHIS2 Initiated');
		    that.SetStatusAsLoading(false);
		    that.PollImportStatus(that);
		}
		
	    });
	    
	}
	
    };
    xhr.send(msg);
};

