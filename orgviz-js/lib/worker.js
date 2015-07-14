var httpRequest; //{{{
function makeRequest(url, readystatechange) {
  if (window.XMLHttpRequest) { // Mozilla, Safari, ...
    httpRequest = new XMLHttpRequest();
  } else if (window.ActiveXObject) { // IE
    try {
      httpRequest = new ActiveXObject("Msxml2.XMLHTTP");
    } 
    catch (e) {
      try {
        httpRequest = new ActiveXObject("Microsoft.XMLHTTP");
      } 
      catch (e) {}
    }
  }

  if (!httpRequest) {
    //alert('Giving up :( Cannot create an XMLHTTP instance');
    return false;
  }
  httpRequest.onreadystatechange = readystatechange;
  httpRequest.open('GET', url);
  httpRequest.send();
} //}}}

var orgfile = "https://raph.cs.univie.ac.at/organisation.xml";

var GraphWorker = function(file,xpath,subjects,nopts){
    this.nodes = [];

    var schema;
    function setSchema() {
      if (httpRequest.readyState === 4) {
        if (httpRequest.status === 200) {
          schema = responseText;
        } else {
          schema = null;
        }
      }
    } 
    
    makeRequest(orgfile, setSchema);
    if(!schema) return false;
    // validate Schema?

}

