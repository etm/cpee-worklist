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
                               XPathResult.ORDERED_NODE_ITERATOR_TYPE,
                               null);
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
        nodes.push(curr);
        var parser = new DOMParser();
        var xmlNode = parser.parseFromString(node.outerHTML, "text/xml");
        var parentsIterator = xmlNode.evaluate( "//o:parent",
                                                xmlNode,
                                                nsResolver,
                                                XPathResult.ANY_TYPE,
                                                null);
        var parents = parentsIterator.iterateNext();
        for(; parents && !parents.invalidIteratorState; ) {
          console.log(parents);
          parents = parentsIterator.iterateNext();
        }

        node = evalue.iterateNext()
    }
    console.log(nodes);
  }
}

