var orgfile = "http://cpee.org/~demo/orgviz/organisation_informatik.xml";

var GraphWorker = function(file,xpath,subjects,nopts){
  this.nodes = [];
  this.subjects = [];

  function handler(response) {
    if(this.status == 200 && this.responseXML != null )
    {
      console.log(this.responseXML);
      processData(this.responseXML);
    } else {
      console.log("schas")
    }
  }

  var client = new XMLHttpRequest();
  var response;
  client.onload = handler(response);
  client.open("GET", orgfile, true);
  client.send(null);

  function nsResolver(prefix) {
    return prefix == 'o' ? "http://cpee.org/ns/organisation/1.0" : null ;
  }

  function processData(data) {
    var evalue = data.evaluate('/o:organisation/o:units/o:unit|/o:organisation/o:roles/o:role',
                               data,
                               nsResolver,
                               XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                               null);
    // Nodes //{{{
    var node = evalue.iterateNext();
    for(; node && !node.invalidIteratorState; ) {
      var type = node.prefix ? node.prefix + ":" : "" + node.localName
      var id = node.id
      var curr = new Node(id, type, nopts);
      var numsubjects = data.evaluate('count(' + subjects.replace(/\/*$/,'') + '[o:relation[@' + type + '="' + id + '"]])',
                                      data,
                                      nsResolver,
                                      XPathResult.NUMBER_TYPE,
                                      null);
      curr.numsubjects = numsubjects.numberValue;
      
      for(var i = 0; i < node.childNodes.length; ++i) {
        var child = node.childNodes[i];
        if(child.nodeName == "parent") {
          var pa = child.textContent;
          for(var j = 0; j < node.parentNode.childNodes.length; ++j) {
            var pid = node.parentNode.childNodes[j];
            if(pid.id == pa) {
              curr.parents.push([type, pa]);
            }
          }
        }
      }

      nodes.push(curr);
      node = evalue.iterateNext()
    }
  } //}}}
  
  // Subjects


}

