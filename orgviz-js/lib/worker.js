var orgfile = "http://cpee.org/~demo/orgviz/organisation_informatik.xml";

var GraphWorker = function(file,xpath,subjects,nopts){
  this.nodes = [];
  
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
                               XPathResult.ANY_TYPE,
                               null);
    console.log("blubb")
    var node = evalue.iterateNext();
    for(; node && !node.invalidIteratorState; ) {
        var curr = Node(node.id, node.prefix ? node.prefix + ":" : "" + node.localName, nopts);
        nodes.push(curr);
        node = evalue.iterateNext()
    }
    console.log(nodes);
    console.log(ids);
    console.log(types);
  }


}

