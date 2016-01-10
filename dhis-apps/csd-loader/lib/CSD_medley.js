

var CSDLoader = function(form) {
    this.form = form;
    this.status = $(window).find( "#status" );
    this.BaseURL = window.location.protocol + '//' + window.location.host + '/ILR/CSD';
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

CSDLoader.prototype.Alert = function(text) {
    this.Log(text);
    alert(text);
};

CSDLoader.prototype.BindActions = function() {
    if (!this.form) {
	return;
    }

    this.form.click(  $.proxy(function(event) {
	//save the orgin of every click within this form so we can recover submission button
	$(this).data('clicked',$(event.target))
    },this)),
    
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
	default:
	    this.Alert('Unrecognzied Action: ' + action);		
	}
		
    },this)),


    this.form.find('select[name=docs]').change( $.proxy( function() {
        this.UpdateSelection();
    },this));

    this.form.find('select[name=org]').change( $.proxy( function() {
	this.UpdateSelection();
    },this));
    }



CSDLoader.prototype.LoadDocs = function() {
    
    var docs = this.form.find('select[name=docs]');
    if (!docs) {
	return;
    }
    this.Log('getting docs');
    $.ajax({
	url: this.BaseURL + '/documents.json',
	contentType: 'application/json',
	dataType: "text",
	cache: false,
	context: this,
	error: $.proxy(function() {
	    this.Log('error on fetch');
	    this.Alert('Could not load the documents');
	},this),
	success: $.proxy(function(json) {
	    this.Log('got documents' + json);
	    docs.empty();
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
    this.Log('OK');
    var doc = this.form.find('select[name=docs] option:selected').val();
    var url  = this.BaseURL + '/csr/' + doc + '/careServicesRequest/urn:ihe:iti:csd:2014:stored-function:organization-search';
    var selected = this.form.find('select[name=org] option:selected')
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
	    var logger = this.Log
	    $(xml).find("csd\\:organization,organization").each(
	        function() {
		    logger(this);
		    var id = $(this).attr('entityID');
		    var name = $(this).find('csd\\:primaryName').text();
		    logger('Adding: ' + id + ' ' + name);
		    select.append("<option value='" + id + "'>" + name + "</option>");
		});
	    this.Log('updated dropdown');
	    return true;
	},this)
    });
   
};


CSDLoader.prototype.ImportSelected = function() {
    this.Alert('Exporting');
};

CSDLoader.prototype.ImportSelected = function() {
    this.UpdateStatus('Beginning Data Import');
    var doc = this.form.find('select[name=docs] option:selected').val();
    var url  = this.BaseURL + '/csr/' + doc + '/careServicesRequest/urn:dhis.org:transform_to_dxf:v2.19';
    var selected = this.form.find('select[name=org] option:selected')
    var parentID = selected.val();
    var msg ="<csd:requestParams xmlns:csd='urn:ihe:iti:csd:2013'><csd:organization entityID='" + parentID + "'/></csd:requestParams>";
    this.UpdateStatus('Requesting Data From ILR');
    this.Log('SENDING to ' + url + "\n" + msg);
    $.ajax({
	method:'POST',
	type: 'POST',
	url:url,
	data:msg,
	contentType: 'text/xml',
	dataType: "xml",
	context: this,
	cache: false,
	error: function() {
	    this.Alert('Could not load the selected organisation units');
	    this.UpdateStatus('Request For Data From ILR Failed');
	},
	success: function(xml) {
	    this.UpdateStatus('Sending Data For Import To DHIS2');
	    this.Log("Received\n" +  this.xmlSerializer.serializeToString(xml));
	    $.ajax({
	        url: '../api/metadata',
	        method: 'POST',
	        type: 'POST',
		context: this,
		data:  this.xmlSerializer.serializeToString(xml),
		contentType: 'application/xml',
		error: function() {
		    this.Alert('Could not upload the metadata');
		    this.UpdateStatus('Data Import On DHIS2 Failed');},
		success: function(xmlResponse) {
		    this.Log("Received\n" +   xmlResponse);		    
		    this.UpdateStatus('Data Import On DHIS2 Initiated');
		}
		
	    });
	    }
        });
};
